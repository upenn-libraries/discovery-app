
# overrides for blacklight's CatalogHelper
module CatalogHelper
  include Blacklight::CatalogHelperBehavior
  include BlacklightAlma::CatalogOverride #EXTRACT:candidate Xapp/helpers/catalog_helper.rb
end
