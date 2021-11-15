
# Blacklight overrides
module BlacklightHelper
  include Blacklight::BlacklightHelperBehavior

  # override Blacklight to replace the default bar (containing simple search form)
  # with our fancy tabbed search bar
  def render_search_bar
    render partial: 'catalog/franklin_search_bar'
  end

  EXPERT_HELP_CORRELATION_THRESHOLD = 0.3

  def render_expert_help(specialists_facet_field)
    return render partial: 'catalog/ask' unless specialists_facet_field
    specialists = extract_and_sort_by_relatedness(specialists_facet_field)
    if specialists.blank? || specialists.first.subs[:r1][:relatedness] < EXPERT_HELP_CORRELATION_THRESHOLD
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

  # digs down past the top-level domain-restricting facet query, to the relevant
  # facet items, screens out values where relatedness is nil or not applicable,
  # and sorts by associated relatedness. Returns an array of facet
  # items, sorted by relatedness
  def extract_and_sort_by_relatedness(specialists_facet_field)
    specialists_facet_field.items[0].subs.each_with_object([]) do |(k, v), arr|
      if k != :count && v.subs[:r1]
        arr << v
      end
    end.sort! { |a,b| b.subs[:r1][:relatedness] <=> a.subs[:r1][:relatedness] }
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

  # @param [SolrDocument] doc
  # @return [TrueClass, FalseClass]
  def show_cataloging_error_link?(doc)
    return false unless current_user

    return false unless doc.alma_mms_id.present?

    true
  end

  # @param [String] mms_id
  # @return [String]
  def cataloging_error_path(mms_id)
    link_to t('blacklight.tools.cataloging_error'), "/redir/enhanced?bibid=#{mms_id}"
  end

end
