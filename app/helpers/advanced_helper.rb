module AdvancedHelper
  include BlacklightAdvancedSearch::AdvancedHelperBehavior

  def facet_field_names_for_advanced_search
    # exclude pub date range facet, b/c it has a form, which nests insid
    # the advanced search form and causes havoc
    blacklight_config.facet_fields.values.select { |f| !f.xfacet && f.field != 'pub_date_isort' }.map(&:field)
  end

end