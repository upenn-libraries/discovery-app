
# Blacklight overrides
module BlacklightHelper
  include Blacklight::BlacklightHelperBehavior

  # override Blacklight to replace the default bar (containing simple search form)
  # with our fancy tabbed search bar
  def render_search_bar
    render partial: 'catalog/franklin_search_bar'
  end

  def render_expert_help(specialists)
    return unless specialists
    specialists = specialists.items[0].subs.each_with_object([]) do |(k, v), arr|
      if k != :count && v.subs[:r1]
        arr << v
      end
    end.sort! { |a,b| b.subs[:r1][:relatedness] <=> a.subs[:r1][:relatedness] }
    if specialists.blank? || specialists.first.subs[:r1][:relatedness] < 0.3
      return render partial: 'catalog/ask'
    end
    subject = specialists.first.value
    specialist_data = PennLib::SubjectSpecialists.data
    relevant_specialists = specialist_data[subject]
    if relevant_specialists.present?
      render partial: 'catalog/expert_help',
             locals: { specialist: relevant_specialists.sample, subject: subject.to_s }
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
