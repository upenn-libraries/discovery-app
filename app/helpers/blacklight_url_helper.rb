
module BlacklightUrlHelper
  include Blacklight::UrlHelperBehavior

  # override so Start Over always goes to catalog search (not landing page)
  def start_over_path(query_params = params)
    search_catalog_path
  end

end
