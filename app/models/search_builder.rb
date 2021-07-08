# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_search_to_solr, :manipulate_sort_and_rows_params, :modify_combo_param_with_absent_q,
      :lowercase_expert_boolean_operators, :add_left_anchored_title, :add_routing_hash]
  include BlacklightSolrplugins::FacetFieldsQueryFilter

  ##
  # NOTE: this is patterned off an analogous method in lib/blacklight/configuration/context.rb
  # NOTE: It *may* be possible to access the original method from here, but I couldn't figure out how
  # NOTE: In stock BL, these conditionals are only checked to determine whether to *render* the facets
  # NOTE: We evaluate here to prevent making expensive facet requests that will just be ignored!
  # Evaluate conditionals for a configuration with if/unless attributes
  #
  # @param [#if,#unless] config an object that responds to if/unless
  # @return [Boolean]
  def evaluate_if_unless_configuration(config, blacklight_params)
    return config if config == true or config == false

    params_context = Object.new
    params_context.define_singleton_method(:params) do
      blacklight_params
    end

    if_value = !config.respond_to?(:if) ||
                    config.if.blank? || config.if == true ||
                    config.if.call(params_context, nil, nil)

    unless_value = !config.respond_to?(:unless) ||
                    config.unless.blank? ||
                    !config.unless.call(params_context, nil, nil)

    if_value && unless_value
  end

  class DummyConfig
    attr_reader :if, :unless
    def initialize(if_condition, unless_condition)
      @if = if_condition
      @unless = unless_condition
    end
  end

  ##
  # Add appropriate Solr facetting directives in, including
  # taking account of our facet paging/'more'.  This is not
  # about solr 'fq', this is about solr facet.* params.
  def add_facetting_to_solr(solr_parameters)
    # NOTE: `facet=false` is a Solr concept; although this param is ignored in stock BL as a
    # BL param, it's useful to support this at the BL level; esp. because I think `facet=false`
    # in Solr does not disable "JSON Facet API" faceting!
    return if blacklight_params[:facet] == false # default true, so distinguish from falsey `nil`
    return if blacklight_params[:action] == 'facet' # any faceting should be added by add_facet_paging_to_solr
    facet_fields_to_include_in_request.each do |field_name, facet|
      next unless evaluate_if_unless_configuration(facet, blacklight_params)
      solr_parameters[:facet] ||= true

      sort = facet.sort
      limit = facet_limit_with_pagination(field_name)
      json_facet = add_json_facet(solr_parameters, facet, limit, 0, sort, nil)
      next if json_facet == true || json_facet.nil?
      if json_facet
        # if json_facet is not explicitly "false", it represents the fallback sort value
        sort = json_facet
      end

      if facet.pivot
        solr_parameters.append_facet_pivot with_ex_local_param(facet.ex, facet.pivot.join(","))
      elsif facet.query
        solr_parameters.append_facet_query facet.query.map { |k, x| with_ex_local_param(facet.ex, x[:fq]) }
      else
        solr_parameters.append_facet_fields with_ex_local_param(facet.ex, facet.field)
      end

      if sort
        solr_parameters[:"f.#{facet.field}.facet.sort"] = sort
      end

      if facet.solr_params
        facet.solr_params.each do |k, v|
          solr_parameters[:"f.#{facet.field}.#{k}"] = v
        end
      end

      solr_parameters[:"f.#{facet.field}.facet.limit"] = limit if limit
    end
  end

  def add_json_facet(solr_params, facet_config, limit = nil, offset = nil, sort = nil, prefix = nil)
    limit ||= facet_config.limit
    offset ||= 0
    sort ||= facet_config.sort
    json_facet_config = facet_config.json_facet
    return false unless json_facet_config # no json_facet key configured
    condition = lambda { |if_condition, unless_condition|
      evaluate_if_unless_configuration(DummyConfig.new(if_condition, unless_condition), blacklight_params)
    }
    json_facet_spec = json_facet_config.get_json_facet_request(facet_config.key, facet_config.field, limit, offset, sort, prefix, condition)
    if json_facet_spec.nil?
      return false # fallback to legacy facets
    elsif json_facet_spec[:request]
      # we have a spec and a request, so add request and return true, bypassing legacy processing
      (solr_params[:'json.facet'] ||= []) << json_facet_spec[:request]
      return true
    else
      fallback = json_facet_spec[:fallback] # must be present
      # nil return value shortcircuits this facet field. Nothing will be added to the request
      return nil unless evaluate_if_unless_configuration(DummyConfig.new(fallback[:if], fallback[:unless]), blacklight_params)
      map_sort = fallback[:map_sort]
      return false unless map_sort
      map_sort.call(sort, blacklight_params)
    end
  end

  def add_facet_paging_to_solr(solr_params)
    return unless facet.present?

    facet_config = blacklight_config.facet_fields[facet]

    # Now override with our specific things for fetching facet values
    facet_ex = facet_config.respond_to?(:ex) ? facet_config.ex : nil

    limit = if scope.respond_to?(:facet_list_limit)
              scope.facet_list_limit.to_s.to_i
            elsif solr_params["facet.limit"]
              solr_params["facet.limit"].to_i
            else
              facet_config.fetch(:more_limit, 20)
            end

    page = blacklight_params.fetch(request_keys[:page], 1).to_i
    offset = (page - 1) * limit

    sort = blacklight_params[request_keys[:sort]]
    prefix = blacklight_params[request_keys[:prefix]]

    json_facet = add_json_facet(solr_params, facet_config, limit + 1, offset, sort, prefix)
    return if json_facet == true || json_facet.nil?
    if json_facet
      # if json_facet is not explicitly "false", it represents the fallback sort value
      sort = json_facet
    end

    solr_params[:"facet.field"] = with_ex_local_param(facet_ex, facet_config.field)

    # Need to set as f.facet_field.facet.* to make sure we
    # override any field-specific default in the solr request handler.
    solr_params[:"f.#{facet_config.field}.facet.limit"] = limit + 1
    solr_params[:"f.#{facet_config.field}.facet.offset"] = offset
    if blacklight_params[request_keys[:sort]]
      solr_params[:"f.#{facet_config.field}.facet.sort"] = sort
    end
    if blacklight_params[request_keys[:prefix]]
      solr_params[:"f.#{facet_config.field}.facet.prefix"] = prefix
    end

    if facet_config.solr_params
      facet_config.solr_params.each do |k, v|
        solr_params[:"f.#{facet_config.field}.#{k}"] = v
      end
    end

    solr_params[:rows] = 0
  end

  # override #with to massage params before this SearchBuilder
  # stores and works with them
  def with(blacklight_params = {})
    params_copy = blacklight_params.dup
    blacklight_params.delete(:routingHash)
    if params_copy[:q].present?
      # #add_query_to_solr assumes the presence of search_field, which we don't set
      # on bento page, so we set it here if absent. we MUST do this, otherwise
      # the code that adds the field's solr_local_parameters, which we use to
      # set qf/pf params, won't run.
      search_field = params_copy[:search_field] || default_search_field.field
      params_copy[:search_field] = search_field
      if search_field != 'keyword_expert' && !is_advanced_search?
        params_copy[:q] = params_copy[:q].gsub(/[\?]/, '')
      end
      # colons surrounded by whitespace cause Solr to return 0 results
      params_copy[:q] = params_copy[:q].gsub(/\s+:\s+/, ' ')
      if search_field == 'keyword_expert'
        params_copy[:q] = params_copy[:q].gsub(/(^| )bib_id:([0-9]+)/, '\1alma_mms_id:99\23503681')
      end
    end
    super(params_copy)
  end

  def add_left_anchored_title(solr_parameters)
    qq = solr_parameters[:qq]
    return unless qq.present?
    bq = blacklight_params[:q]
    return unless bq.present?
    search_field = blacklight_params[:search_field]
    return if search_field.present? && search_field != 'keyword'
    weight = '26'
    augmented_solr_q = '{!maxscore}'\
        "_query_:\"{!field f='title_1_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_2_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_3_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_4_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_5_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_6_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_7_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_8_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_9_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_10_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_11_tl' v=$qq}\"^#{weight} OR "\
        "_query_:\"{!field f='title_12_tl' v=$qq}\"^#{weight} OR "\
        '_query_:"' + solr_parameters[:q] + '"'
    solr_parameters[:q] = augmented_solr_q
  end

  def modify_combo_param_with_absent_q(solr_parameters)
    if !blacklight_params[:q].present?
      if blacklight_params[:f].present?
        # we have user filters, so avoid NPE by ignoring q in combo domain
        # below replicates the default `combo` param, but without `q`. the `no_correlation`
        # tag convention allows filters to be tagged for exclusion so they do not restrict
        # the domains used to determine correlation.
        solr_parameters['combo'] = '{!filters param=$fq excludeTags=cluster,no_correlation}' # NOTE: $correlation_domain is applied within facets
      else
        # no user input, so remove pointless "combo" arg
        # if any facets have been mistakenly added that reference $combo, they
        # will fail
        solr_parameters.delete('combo')
      end
    end
  end

  # `sort` and `rows` params may want changes (for logic, predictability, or
  # performance) under certain conditions. This method bundles all such changes
  # together because they all operate on the same params, and thus cannot easily
  # be functionally/independently applied without actually making things *more*
  # confusing.
  def manipulate_sort_and_rows_params(solr_parameters)
    blacklight_sort = blacklight_params[:sort]
    if blacklight_params[:action] == 'bento'
      # rows should never be 0; skip next conditional clauses
    elsif blacklight_params[:q].nil? && blacklight_params[:f].nil? && blacklight_params[:search_field].blank?
      # these are conditions under which no actual record results are displayed; so set rows=0
      # `:landing` action should also be caught by this block
      solr_parameters[:sort] = ''
      solr_parameters[:rows] = 0
      return
    elsif blacklight_params[:search_field] == 'subject_correlation'
      solr_parameters[:presentation_domain] = '{!filters param=$fq excludeTags=cluster,no_correlation}'
      solr_parameters[:sort] = ''
      solr_parameters[:rows] = 0
      return
    end
    return if blacklight_sort.present? && blacklight_sort != 'score desc'
    access_f = blacklight_params.dig(:f, :access_f)
    if !blacklight_params[:q].present?
      # no q param (with or without facets) causes the default 'score' sort
      # to return results in a different random order each time b/c there's
      # no scoring to apply. if there's no q and user hasn't explicitly chosen
      # a sort, we sort by id to provide stable deterministic ordering.
      if blacklight_config.induce_sort
        induced_sort = blacklight_config.induce_sort.call(blacklight_params)
        if induced_sort
          solr_parameters[:sort] = induced_sort
          return
        end
      end
      sort = 'elvl_rank_isort asc,last_update_isort desc'
      if access_f.nil? || access_f.empty?
	# nothing
      elsif access_f.include? 'At the library'
        if access_f.size == 1
          # privilege physical holdings
          sort = "min(def(hld_count_isort,0),1) desc,#{sort}"
        end
      else
	# privilege online holdings
        sort = "min(def(prt_count_isort,0),1) desc,#{sort}"
      end
    else
      sort = solr_parameters[:sort]
      sort = 'score desc' if !sort.present?
      if access_f == nil || access_f.empty?
        sort << @@DEFAULT_INDUCED_SORT
      elsif access_f.size == 1 && access_f.first == 'At the library'
        sort << @@AT_THE_LIBRARY_INDUCED_SORT
      else
        sort << @@ONLINE_INDUCED_SORT
      end
    end
    solr_parameters[:sort] = sort
  end

  @@ONLINE_INDUCED_SORT = ',' + [
    "pub_max_dtsort desc,",
    "if(exists(prt_count_isort),",
      "sum(",
        "if(termfreq(format_f,'Journal/Periodical'),",
          "1,", # add 1 to boost journals
          "0",
        "),",
        "min(prt_count_isort,10)", # cap to 10, higher is noise
      "),",
      "0",
    ") desc,",
    "min(def(hld_count_isort,0),10) desc,", # physical hldgs, if any, capped to 10
    "last_update_isort desc"
  ].join

  @@AT_THE_LIBRARY_INDUCED_SORT = ',' + [
    "pub_max_dtsort desc,",
    "if(exists(hld_count_isort),",
       "sum(",
         "if(termfreq(format_f,'Journal/Periodical'),",
           "1,", # add 1 to boost journals
           "0",
         "),",
         "min(hld_count_isort,10)", # cap to 10; higher is noise
       "),",
       "0",
     ") desc,",
     "min(def(prt_count_isort,0),10) desc,", # online hldgs, if any, capped to 10
     "last_update_isort desc"
  ].join

  @@DEFAULT_INDUCED_SORT = ',' + [
    "pub_max_dtsort desc,",
    "max(",
      "if(exists(hld_count_isort),",
        "sum(",
          "if(termfreq(format_f,'Journal/Periodical'),",
            "2,", # add 2 to boost physical journals
            "0", # default boost of 0
          "),",
          "min(hld_count_isort,10)", #cap to 10; higher is noise
        "),",
        "0",
      "),",
      "if(exists(prt_count_isort),",
        "sum(",
          "if(termfreq(format_f,'Journal/Periodical'),",
            "3,", # add 2 to boost online journals
            "1", # add 1 to boost online
          "),",
          "min(prt_count_isort,10)", #cap to 10; higher is noise
        "),",
        "0",
      ")",
    ") desc,",
    "last_update_isort desc"
  ].join

  def lowercase_expert_boolean_operators(solr_parameters)
    search_field = blacklight_params[:search_field]
    if search_field == 'keyword_expert'
      solr_parameters[:lowercaseOperators] = true
    end
  end

  def add_routing_hash(solr_parameters)
    routing_hash = blacklight_params[:routingHash]
    return if routing_hash.nil?
    solr_parameters[:routingHash] = routing_hash
  end

end
