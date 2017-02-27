
module BlacklightAlmaHelper
  include BlacklightAlma::HelperBehavior

  def alma_service_type_for_fulfillment_url(document)
    if document.has?('physical_holdings_json').present?
      'getit'
    else
      'viewit'
    end
  end

end
