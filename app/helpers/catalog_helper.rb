# overrides for blacklight's CatalogHelper
module CatalogHelper
  include Blacklight::CatalogHelperBehavior
  include BlacklightAlma::CatalogOverride

  # @param [Hash] options
  def relevance_score(options)
    values = options[:value]
    "Relevance Score: #{values.first}"
  end
end
