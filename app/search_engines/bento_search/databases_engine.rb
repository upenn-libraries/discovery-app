# Perform search and build Bento objects
class BentoSearch::DatabasesEngine
  include BentoSearch::SearchEngine
  include Blacklight::SearchHelper

  # search_results needs a blacklight_config
  # this can't be the best way to get our config, right?
  # @return [Blacklight::Configuration]
  def blacklight_config
    CatalogController.new.blacklight_config
  end

  # This method is called by BentoSearch
  # @param [Hash] args
  # @return [BentoSearch::Results]
  def search_implementation(args)
    return if args[:query].nil?

    response = blacklight_results args
    bs_results = BentoSearch::Results.new
    bs_results.total_items = response.first.dig('response', 'numFound')
    docs = response.first.docs
    return bs_results if docs.empty?

    docs.each do |doc|
      bs_results << build_bento_item(doc)
    end
    bs_results
  end

  # Do BL search and get SolrDocuments
  # @param [Hash] args
  # @return [Blacklight::Solr::Response]
  def blacklight_results(args)
    search_results(
      q: args[:query],
      per_page: 5,
      facet: false,
      search_field: 'keyword',
      f: { 'format_f': [PennLib::Marc::DATABASES_FACET_VALUE] }
    )
  end

  # Build a BentoSearch::Item from a SolrDocument
  # @param [SolrDocument] doc
  # @return [BentoSearch::ResultItem]
  def build_bento_item(doc)
    links = {}
    doc['full_text_link_text_a']&.each do |link_hash|
      link_info = JSON.parse(link_hash).first
      links[link_info['linkurl']] = link_info['linktext'].strip
    end
    BentoSearch::ResultItem.new(title: doc['title'].strip.html_safe,
                                link: Rails.application.routes.url_helpers
                                           .solr_document_path(doc['id']),
                                publisher: doc['publication_a']&.first,
                                other_links: links)
  end
end
