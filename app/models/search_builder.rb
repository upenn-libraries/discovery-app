# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_parse_q_to_solr, :add_advanced_search_to_solr, :add_fq_for_multiple_access_facets ]
  include BlacklightRangeLimit::RangeLimitBuilder
  include BlacklightSolrplugins::FacetFieldsQueryFilter

  # this adds fq params for the Access facet, which needs
  # to be handled differently to apply to clusters of documents,
  # instead of just documents.
  def add_fq_for_multiple_access_facets(solr_parameters)
    facets = blacklight_params['f'] || {}
    selected_values = facets['access_f'] || []
    if selected_values.member?('At the library') && selected_values.member?('Online')
      solr_parameters.append_filter_query(
        %q~filter({!join from=cluster_id to=cluster_id_online v='access_f:"At the library"'}) filter({!join from=cluster_id to=cluster_id_at_library v='access_f:Online'})~)
    elsif selected_values.member?('At the library')
      solr_parameters.append_filter_query(
        %q~{!join from=cluster_id_at_library to=cluster_id v='*:*'}~)
    elsif selected_values.member?('Online')
      solr_parameters.append_filter_query(
        %q~{!join from=cluster_id_online to=cluster_id v='*:*'}~)
    end
  end

  # override from SearchBuilderBehavior: skip handling of
  # access_f, since that is handled by #add_fq_for_multiple_access_facets
  def facet_value_to_fq_string(facet_field, value)
    if facet_field != 'access_f'
      super(facet_field, value)
    end
  end

end
