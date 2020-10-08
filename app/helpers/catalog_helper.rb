# overrides for blacklight's CatalogHelper
module CatalogHelper
  include Blacklight::CatalogHelperBehavior
  include BlacklightAlma::CatalogOverride
end
