
class FranklinAlmaController < BlacklightAlma::AlmaController

  def alma_api_class
    PennLib::BlacklightAlma::AvailabilityApi
  end

  def single_availability
    mmsid = params[:mmsid]
    api = alma_api_class.new()
    response_data = api.get_availability([mmsid])
    request_options = ['Hold Request', 'Interlibrary Loan', 'Books by Mail', 'Place on Course Reserve', 'Request Fix / Enhance Record', 'Scan &amp; Deliver', 'Send us a Question']
    table_data = response_data['availability'][mmsid]['holdings'].map { |h| [h['location'], h['availability'], h['call_number'], '<a href="#">View Shelf Location</a>'] }

    #render :json => {"data": [["Location of #{mmsid}", 'Availability', 'Call #', 'Details button']]}
    render :json => {"data": table_data}
  end

end
