# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_search_to_solr, :override_sort_when_q_is_empty, :lowercase_expert_boolean_operators,
      :add_left_anchored_title, :add_routing_hash, :add_cluster_params]
  include BlacklightRangeLimit::RangeLimitBuilder
  include BlacklightSolrplugins::FacetFieldsQueryFilter

  ##
  # Add appropriate Solr facetting directives in, including
  # taking account of our facet paging/'more'.  This is not
  # about solr 'fq', this is about solr facet.* params.
  def add_facetting_to_solr(solr_parameters)
    facet_fields_to_include_in_request.each do |field_name, facet|
      solr_parameters[:facet] ||= true

      if facet.json_facet
        json_facet = (solr_parameters[:'json.facet'] ||= [])
        json_facet << facet.json_facet
        next
      end

      if facet.pivot
        solr_parameters.append_facet_pivot with_ex_local_param(facet.ex, facet.pivot.join(","))
      elsif facet.query
        solr_parameters.append_facet_query facet.query.map { |k, x| with_ex_local_param(facet.ex, x[:fq]) }
      else
        solr_parameters.append_facet_fields with_ex_local_param(facet.ex, facet.field)
      end

      if facet.sort
        solr_parameters[:"f.#{facet.field}.facet.sort"] = facet.sort
      end

      if facet.solr_params
        facet.solr_params.each do |k, v|
          solr_parameters[:"f.#{facet.field}.#{k}"] = v
        end
      end

      limit = facet_limit_with_pagination(field_name)
      solr_parameters[:"f.#{facet.field}.facet.limit"] = limit if limit
    end
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

  @@record_sources = ['Brown', 'Chicago', 'Columbia', 'Cornell', 'Duke', 'Harvard', 'Penn', 'Princeton', 'Stanford', 'HathiTrust']

  def add_cluster_params(solr_parameters)
    if 'Dynamic' == blacklight_params.dig(:f, :cluster, 0)
      solr_parameters[:fq] << '{!collapse tag=cluster ex=cluster field=cluster_id nullPolicy=expand size=3000000}'
    end
    source_idx = 0
    loop do
      solr_parameters["j#{source_idx}"] = "{!join from=cluster_id to=cluster_id v=record_source_f:#{@@record_sources[source_idx]}}"
      other_sources = @@record_sources.dup
      cluster = other_sources.delete_at(source_idx)
      clause = 0
      loop do
        if source_idx >= clause
          join_filter_idx = clause == 0 ? clause : clause - 1
          if source_idx == clause
            other_filter_label = "o#{clause}"
          else
            other_filter_label = "o#{clause}_#{source_idx}"
          end
          solr_parameters[other_filter_label] = "record_source_f:(#{other_sources.join(' OR ')})"
          solr_parameters["x#{clause}_#{source_idx}"] = "{!bool filter=$j#{join_filter_idx} filter=$#{other_filter_label}}"
        end
        break if other_sources.length == 1
        cluster = other_sources.shift
        clause += 1
      end
      last_source_idx = source_idx
      break unless (source_idx += 1) < @@record_sources.length
      if source_idx != 0
        solr_parameters["x#{last_source_idx}"] = "{!bool filter=$j#{last_source_idx} filter=$o#{last_source_idx}}"
      end
    end
  end

  def add_left_anchored_title(solr_parameters)
    qq = solr_parameters[:qq]
    return if qq.nil? || !qq.present?
    bq = blacklight_params[:q]
    return if !bq.present?
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

  # no q param (with or without facets) causes the default 'score' sort
  # to return results in a different random order each time b/c there's
  # no scoring to apply. if there's no q and user hasn't explicitly chosen
  # a sort, we sort by id to provide stable deterministic ordering.
  def override_sort_when_q_is_empty(solr_parameters)
    blacklight_sort = blacklight_params[:sort]
    return if blacklight_sort.present? && blacklight_sort != 'score desc'
    access_f = blacklight_params.dig(:f, :access_f)
    if !blacklight_params[:q].present?
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
