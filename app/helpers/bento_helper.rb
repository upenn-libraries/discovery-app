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
    online_links_arr = []
    has_hathi_link = dedupe_hathi(document.full_text_links_for_cluster_display, online_links_arr)
    # online holdings are not necessarily represented in 'full_text_link_text_a'
    # derive the canonical `links_count` from `prt_count_isort`, possibly incremented by hathi holding
    # where legit holding has no link, below prevents Hathi holdings from masking the presence of "real" online holding
    links_count = (document['prt_count_isort'] || 0) + (has_hathi_link ? 1 : 0)
    if links_count == 1 && online_links_arr.size == 1
      fulltext_link_for online_links_arr.first
    elsif document['prt_count_isort'].nil?
      nil # this is primarily a physical item
    else
      url = solr_document_path document.id
      text = "#{links_count} online #{'option'.pluralize(links_count)}"
      link_to text, url
    end
  end

  HATHI_PD_TEXT = 'HathiTrust Digital Library Connect to full text'
  HATHI_ETAS_POSTFIX = ' from HathiTrust during COVID-19'
  HATHI_LOGIN_PREFIX = 'https://babel.hathitrust.org/Shibboleth.sso/Login?entityID=https://idp.pennkey.upenn.edu/idp/shibboleth&target=https%3A%2F%2Fbabel.hathitrust.org%2Fcgi%2Fping%2Fpong%3Ftarget%3D'

  def dedupe_hathi(online_links_arr, result_arr)
    acc = { arr: result_arr }
    online_links_arr.each_with_object(acc) do |v, acc|
      e = JSON.parse(v).first
      if e['linktext'] == HATHI_PD_TEXT
        acc[:pd] = e
      elsif e['postfix'] == HATHI_ETAS_POSTFIX
        e['linkurl'] = HATHI_LOGIN_PREFIX + URI.encode_www_form_component(e['linkurl'])
        acc[:etas] = e
      else
        acc[:arr] << e
      end
    end
    hathi = (acc[:etas] || acc[:pd])
    if hathi.nil?
      return false
    else
      result_arr << hathi
      return true
    end
  end

  # Return a link to full text
  # @param [SolrDocument] document
  # @return [ActiveSupport::SafeBuffer]
  def fulltext_link_for(link_info)
    link_to(link_info['linktext'], link_info['linkurl']) + link_info['postfix']
  end
end
