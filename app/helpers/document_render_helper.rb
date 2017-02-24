
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

  def render_author_with_880(options)
    render_values_with_breaks(options[:value] + options[:document].fetch('author_880_a', []))
  end

  def render_electronic_holdings(options)
    buf = ''
    electronic_holdings = options[:value]
    if electronic_holdings.present?
      # options[:value] is multi-valued even if Solr field is single-valued
      electronic_holdings
          .map { |v| JSON.parse(v) }
          .each do |electronic_holdings_struct|
        content = electronic_holdings_struct.map do |holding|
          url = alma_electronic_resource_direct_link(holding['portfolio_pid'])
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

  def render_online_display_for_show_view(options)
    online_display_values = options[:value]
    online_display_values.map do |online_display|
      content_tag('a', online_display[:linktext], { href: online_display[:linkurl] }) + '<br/>'.html_safe +
          online_display[:linkurl]
    end.join.html_safe
  end

  def render_online_display_for_index_view(options)
    online_display_values = options[:value]
    online_display_values.map do |online_display|
      content_tag('a', online_display[:linktext], { href: online_display[:linkurl] })
    end.join.html_safe
  end

  # creates a URL for the given hash record. based on 'link_type' key and other keys
  # @param record [Hash]
  # @return [String] url
  def link_for_link_type(record)
    val = record[:value_for_link] || record[:value]
    case record[:link_type]
      when 'search'
        search_catalog_path(q: val)
      when /_search$/
        search_catalog_path(q: val, search_field: record[:link_type])
      when /_xfacet$/
        xbrowse_catalog_path(record[:link_type], q: val)
      else
        "#UNKNOWN"
    end
  end

  # Render method for document field values that should be linked to a search URL.
  #
  # This gets called by Blacklight, so options[:value] will be an Array.
  # This should consist of Hashes containing the following symbol keys:
  #  value: main value
  #  value_for_link: (optional) this value will be used in the generated search URL, instead of 'value'
  #  value_append: (optional) the value to append after 'value'
  #  link: (optional, default=true) boolean determining whether 'value'
  #    should be linked or just displayed as plain text
  #  link_type: (optional if 'link' is false) string indicating what kind of link to generate
  def render_linked_values(options)
    records = options[:value]
    values = records.map do |record|
      should_link = record[:link].nil? || record[:link]
      text = should_link ? link_to(record[:value], link_for_link_type(record)) : record[:value]
      [ record[:value_prepend], text, record[:value_append] ].select(&:present?).join(' ')
    end
    render_values_with_breaks(values)
  end

end
