# View helper methods for bento display
module BentoHelper
  # Return a link for display as part of a catalog bento result with
  # details about print holdings
  # @param [SolrDocument] document
  # @return [ActiveSupport::SafeBuffer]
  def print_holding_info_for(document)
    # show library and call number if only one holding
    url = solr_document_path document.id
    text = if document['hld_count_isort'] == 1
             single_print_holding_text_for document
           else
             t('franklin.catalog_search.holdings',
               count: document['hld_count_isort'],
               option: 'option'.pluralize(document['hld_count_isort']))
           end
    link_to text, url
  end

  # Return an informative string with the call number and library location name
  # @param [SolrDocument] document
  # @return [String]
  def single_print_holding_text_for(document)
    holding = JSON.parse(document['physical_holdings_json']).first
    library_location = print_holding_location holding
    if library_location
      t('franklin.catalog_search.available_with_location',
        location: library_location,
        classification: holding['classification_part'],
        item: holding['item_part'])
    else
      t('franklin.catalog_search.available',
        classification: holding['classification_part'],
        item: holding['item_part'])
    end
  end

  # Return specific location from holdings_info
  # @param [Hash] holdings_info
  # @return [String, NilClass]
  def print_holding_location(holdings_info)
    return unless holdings_info

    @location_mapper ||= PennLib::CodeMappings.new('./config/translation_maps/')
    xml_location_info = @location_mapper.locations[holdings_info['location']]
    xml_location_info&.dig('specific_location')
  end

  # Return a link for display as part of a catalog bento result with
  # details about electronic holdings
  # @param [SolrDocument] document
  # @return [ActiveSupport::SafeBuffer]
  def online_holding_info_for(document)
    if document['prt_count_isort'] == 1 && document['full_text_link_text_a']
      fulltext_link_for document
    else
      url = solr_document_path document.id
      text = "#{document['prt_count_isort']} online #{'option'.pluralize(document['prt_count_isort'])}"
      link_to text, url
    end
  end

  # Return a link to full text
  # @param [SolrDocument] document
  # @return [ActiveSupport::SafeBuffer]
  def fulltext_link_for(document)
    link_info = JSON.parse(document['full_text_link_text_a'].first)&.first
    link_to link_info['linktext'], link_info['linkurl']
  end
end
