# View helper methods for bento display
module BentoHelper
  # Return a link for display as part of a catalog bento result with
  # details about print holdings
  # @param [SolrDocument] document
  # @return [ActiveSupport::SafeBuffer]
  def print_holding_info_for(document)
    url = solr_document_path document.id
    text = "#{document['hld_count_isort']} print #{'option'.pluralize(document['hld_count_isort'])}"
    link_to text, url
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
