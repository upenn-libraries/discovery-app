# Helpful methods and constants for use in CatalogController's
# wild configure_blacklight call
module PennLib
  module BlacklightConfig
    # lambda to control showing/hiding a view tools element
    USER_LOGGED_IN = lambda do |controller, _, _|
      controller.current_user
    end
  end
end
