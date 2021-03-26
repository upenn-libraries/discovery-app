module RequestsHelper
  # TODO: do a better job of setting OpenURL params, or get from Alma request options API :/
  # @param [String] mms_id
  def ill_request_form_url_for(mms_id)
    "https://franklin.library.upenn.edu/redir/ill?bibid=#{mms_id}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com"
  end

  # @param [String] mms_id
  # @param [String] holding_id
  def aeon_request_form_url_for(mms_id, holding_id)
    "https://franklin.library.upenn.edu/redir/aeon?bibid=#{mms_id}&hldid=#{holding_id}"
  end
end
