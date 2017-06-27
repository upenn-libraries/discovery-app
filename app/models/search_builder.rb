# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_search_to_solr, :override_sort_when_q_is_empty, :lowercase_expert_boolean_operators]
  include BlacklightRangeLimit::RangeLimitBuilder
  include BlacklightSolrplugins::FacetFieldsQueryFilter

  # override #with to massage params before this SearchBuilder
  # stores and works with them
  def with(blacklight_params = {})
    params_copy = blacklight_params.dup
    if params_copy[:q].present?
      search_field = params_copy[:search_field]
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

  # no q param (with or without facets) causes the default 'score' sort
  # to return results in a different random order each time b/c there's
  # no scoring to apply. if there's no q and user hasn't explicitly chosen
  # a sort, we sort by id to provide stable deterministic ordering.
  def override_sort_when_q_is_empty(solr_parameters)
    if !blacklight_params[:q].present? && !blacklight_params[:sort].present?
      solr_parameters[:sort] = 'id asc'
    end
  end

  def lowercase_expert_boolean_operators(solr_parameters)
    search_field = blacklight_params[:search_field]
    if search_field == 'keyword_expert'
      solr_parameters[:lowercaseOperators] = true
    end
  end

end
