module RequestsHelper
  # A backup in case we can't get the nice link from Alma
  # @param [String] mms_id
  # TODO: this will be confusing in non-production environments
  def ill_request_form_url_for(mms_id)
    "https://franklin.library.upenn.edu/redir/ill?bibid=#{mms_id}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com"
  end

  # @param [String] mms_id
  # @param [String] holding_id
  # TODO: this will be confusing in non-production environments
  def aeon_request_form_url_for(mms_id, holding_id)
    "https://franklin.library.upenn.edu/redir/aeon?bibid=#{mms_id}&hldid=#{holding_id}"
  end

  def circulate_modal_title
    if user_is_facex?
      t('requests.modal_titles.confirm.facex')
    else
      t('requests.modal_titles.confirm.circulate')
    end
  end
end
