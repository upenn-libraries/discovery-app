
# Blacklight overrides
module BlacklightHelper
  include Blacklight::BlacklightHelperBehavior

  # override Blacklight to replace the default bar (containing simple search form)
  # with our fancy tabbed search bar
  def render_search_bar
    render partial: 'catalog/franklin_search_bar'
  end

  # override Blacklight so Start Over always goes to catalog start page
  def start_over_path(query_params = params)
    # we do NOT call #search_action_path because it might take us to an
    # "blank" browse page, which is never what we want
    root_path
  end

  # override so that we can insert separators
  def search_fields
    super.map do |option|
      field_def = blacklight_config.search_fields[option[1]]
      separator = (field_def && field_def.separator_beneath) ?
          [ '--------', '--------', { disabled: 'true' } ] : nil
      [ option, separator].compact
    end.flatten(1)
  end

end
