
# helper functions for custom rendering of document fields
module DocumentRenderHelper

  # @param options_or_values [Hash|Array]
  # either a Hash of options populated by Blacklight's add_xxx_field, or
  # an array of values
  def render_values_with_breaks(options_or_values)
    values = options_or_values
    join = false
    if options_or_values.is_a?(Array)
      join = true
    else
      values = options_or_values[:value]
      if values.is_a?(Array)
        join = true
      end
    end
    join ? values.join('<br/>').html_safe : values
  end

  def render_electronic_holdings(options)
    buf = ''
    electronic_holdings = options[:value]
    if electronic_holdings.present?
      # options[:value] is multi-valued even if Solr field is single-valued
      electronic_holdings.each do |electronic_holdings_json|
        electronic_holdings_struct = JSON.parse(electronic_holdings_json)
        content = electronic_holdings_struct.map do |holding|
          url = holding['url'].gsub(/rft.mms_id=[^&]/, '') +
              "&rfr_id=info:sid/primo.exlibrisgroup.com&svc_dat=viewit&portfolio_pid=#{holding['portfolio_pid']}"
          coverage = holding['coverage'] ? content_tag('span', ' - ' + holding['coverage']) : ''
          link = content_tag('a', holding['collection'], { href: url })
          content_tag('div', link + coverage)
        end.join('')
        content = content.present? ? content : 'No electronic holdings information available'
        buf << content
      end
    end
    buf.html_safe
  end

  def render_author_display(options)
    author_records = options[:value]
    values = author_records.map do |author_record|
      # TODO: normalize URL param value: my:trimTrailingComma(my:normalize-facet($auth))
      link_to(author_record[:author], xbrowse_catalog_path('author_xfacet', q: author_record[:author]))
    end
    render_values_with_breaks(values)
  end

  def render_standardized_title_display(options)
    standardized_title_records = options[:value]
    values = standardized_title_records.map do |standardized_title_record|
      # TODO: normalize URL param value: my:trimTrailingComma(my:normalize-facet($auth))
      link = link_to(standardized_title_record[:title], search_catalog_path(q: standardized_title_record[:title], search_field: 'title_search'))
      [ link, standardized_title_record[:title_extra] ].compact.join(' ')
    end
    render_values_with_breaks(values)
  end

  def render_conference_display(options)
    conference_records = options[:value]
    values = conference_records.map do |conference_record|
      # TODO: normalize URL param value: my:trimTrailingComma(my:normalize-facet($auth))
      link = link_to(conference_record[:conf], xbrowse_catalog_path('author_xfacet', q: conference_record[:conf]))
      [ link, conference_record[:conf_extra] ].compact.join(' ')
    end
    render_values_with_breaks(values)
  end

  def render_series_display(options)
    series_records = options[:value]
    values = series_records.map do |series_record|
      # TODO: normalize URL param value: my:trimTrailingComma(my:normalize-facet($auth))
      search_field = series_record[:link_type].to_s
      if search_field.present?
        text = link_to(series_record[:series], search_catalog_path(q: series_record[:series], search_field: search_field))
      else
        text = series_record[:series]
      end
      [ text, series_record[:series_extra] ].compact.join(' ')
    end
    render_values_with_breaks(values)
  end

end
