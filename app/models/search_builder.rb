# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_parse_q_to_solr, :add_advanced_search_to_solr]
  include BlacklightRangeLimit::RangeLimitBuilder

  # overrides BlacklightAdvancedSearch::AdvancedSearchBuilder#add_advanced_parse_q_to_solr
  # we need the check in this override to prevent browse pages from getting the q param
  # TODO: we can remove this once this PR gets accepted:
  # https://github.com/projectblacklight/blacklight_advanced_search/pull/69
  def add_advanced_parse_q_to_solr(solr_parameters)
    if is_advanced_search?
      super(solr_parameters)
    end
  end

end
