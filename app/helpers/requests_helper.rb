module RequestsHelper
  # TODO: do a better job of setting OpenURL params, or get from Alma request options API :/
  def ill_request_form_url_for(solr_document)
    "https://franklin.library.upenn.edu/redir/ill?rft.mms_id=#{solr_document.alma_mms_id}&rft.stitle=#{solr_document.title_display}&rft.issn=#{solr_document['isbn_a']&.first}&bibid=#{solr_document.alma_mms_id}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com"
  end

  # __HOLDINGID__ is replaced in JS
  def aeon_request_form_url_for(solr_document)
    "https://franklin.library.upenn.edu/redir/aeon?bibid=#{solr_document.alma_mms_id}&hldid=__HOLDINGID__"
  end
end
