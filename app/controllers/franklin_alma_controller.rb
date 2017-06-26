
class FranklinAlmaController < BlacklightAlma::AlmaController

  def alma_api_class
    PennLib::BlacklightAlma::AvailabilityApi
  end

end
