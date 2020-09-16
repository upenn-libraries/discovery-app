
module BlacklightUrlHelper
  include Blacklight::UrlHelperBehavior

  # override so Start Over always goes to catalog search (not landing page)
  def start_over_path(query_params = params) #EXTRACT:wholesale Xapp/helpers/blacklight/url_helper_behavior.rb
    search_catalog_path
  end

end
