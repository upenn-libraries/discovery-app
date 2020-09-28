
# Blacklight overrides
module BlacklightHelper
  include Blacklight::BlacklightHelperBehavior

  # override Blacklight to replace the default bar (containing simple search form)
  # with our fancy tabbed search bar
  def render_search_bar
    render partial: 'catalog/franklin_search_bar'
  end

  def render_expert_help(specialists)
    if specialists.blank? || specialists.items.first.hits < 30_000
      render partial: 'catalog/ask'
      return
    end
    subject = specialists.items.first.value
    specialist_data = PennLib::SubjectSpecialists.data
    relevant_specialists = specialist_data[subject.to_sym]
    if relevant_specialists.present?
      render partial: 'catalog/expert_help',
             locals: { specialist: relevant_specialists.sample, subject: subject }
    else
      # No relevant specialist could be determined - we need to know about this
      Honeybadger.notify "No specialist could be determined for #{subject}"
      render partial: 'catalog/ask'
    end
  end

  # override so that we can insert separators
  def search_fields
    super.map do |option|
      field_def = blacklight_config.search_fields[option[1]]
      separator = (field_def && field_def.separator_beneath) ?
        [ '--------', '--------', { disabled: 'true', class: 'hidden-xs' } ] : nil
      [option, separator].compact
    end.flatten(1)
  end

  def render_other_links(links_hash)
    other_links = ''
    links_hash.each do |url, text|
      other_links << link_to(text, url)
    end

    other_links.html_safe
  end

end
