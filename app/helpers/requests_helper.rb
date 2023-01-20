module RequestsHelper
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

  # @return [Symbol]
  def noncirc_type
    case params[:noncirc]
    when 'reserves' then :reserves
    when 'reference' then :reference
    when 'hsp' then :hsp
    when 'in_house' then :inhouse
    else
      :inhouse
    end
  end

  def circulate_pickup_locations
    return options_for_select TurboAlmaApi::Request::PICKUP_LOCATIONS unless user_is_student?

    options_for_select TurboAlmaApi::Request::PICKUP_LOCATIONS, selected: 'VPLOCKER'
  end
end
