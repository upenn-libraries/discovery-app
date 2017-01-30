
module BlacklightAlmaHelper
  include BlacklightAlma::HelperBehavior

  def alma_service_type_for_fulfillment_url(document)
    if document.has?('electronic_holdings_json').present?
      'viewit'
    else
      'getit'
    end
  end

end
