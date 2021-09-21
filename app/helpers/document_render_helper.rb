
# helper functions for custom rendering of document fields
module DocumentRenderHelper

  # @param options_or_values [Hash|Array]
  # either a Hash of options populated by Blacklight's add_xxx_field, or
  # an array of values
  def render_values_with_breaks(options_or_values)
    values = options_or_values
    separator = '<br/>'
    join = false
    if options_or_values.is_a?(Array)
      join = true
    else
      values = options_or_values[:value]
      if values.is_a?(Array)
        separator = options_or_values[:config][:separator] if options_or_values[:config][:separator]
        join = true
      end
    end
    join ? values.join(separator).html_safe : values
  end

  def render_author_with_880(options)
    render_values_with_breaks(options[:value] + options[:document].fetch('author_880_a', []))
  end

  def record_source_map(options)
    inst = options[:value].first
    BaseIndexer::RecordSource.constants(false).each do |const|
      inst_int = BaseIndexer::RecordSource.const_get(const)
      return const.to_s.humanize if inst_int == inst
    end
  end

  def render_electronic_holdings(options)
    buf = ''
    electronic_holdings = options[:value]
    if electronic_holdings.present?
      # options[:value] is multi-valued
      content = electronic_holdings.map do |electronic_holdings_str|
        render_electronic_holdings_links(electronic_holdings_str)
      end.join
      content = content.present? ? content : 'No electronic holdings information available'
      buf << content
    end
    buf.html_safe
  end

  # this was used to render electronic holdings stored in Solr, prior to certain fields
  # being available through Alma's availability API.
  # it's now obsolete but keeping it around just in case.
  def render_electronic_holdings_links(electronic_holdings_str)
    if electronic_holdings_str.present?
      JSON.parse(electronic_holdings_str).map do |holding|
        url = alma_electronic_resource_direct_link(holding['portfolio_pid'])
        coverage = holding['coverage'] ? content_tag('span', ' - ' + holding['coverage']) : ''
        link = content_tag('a', holding['collection'], { href: url, target: '_blank' })
        content_tag('div', link + coverage)
      end.join.html_safe
    end
  end

  @@HATHI_PD_TEXT = 'HathiTrust Digital Library Connect to full text'
  @@HATHI_ETAS_POSTFIX = ' from HathiTrust during COVID-19'
  @@HATHI_INFO = ' — only for <a data-toggle="tooltip" title="details regarding HathiTrust ETAS access authorization" href="https://guides.library.upenn.edu/hathitrust">students, active faculty, and permanent staff</a>'
  @@HATHI_LOGIN_PREFIX = 'https://babel.hathitrust.org/Shibboleth.sso/Login?entityID=https://idp.pennkey.upenn.edu/idp/shibboleth&target=https%3A%2F%2Fbabel.hathitrust.org%2Fcgi%2Fping%2Fpong%3Ftarget%3D'

  def detect_nocirc(document)
    return nil unless (alma_mms_id = document[:alma_mms_id]).presence
    "<div id=\"items_nocirc-#{alma_mms_id}\" display=\"none\" val=\"#{document[:nocirc_stored_a].first}\"></div>".html_safe
  end

  def render_online_resource_display_for_index_view(options)
    values = options[:value]
    suppress_remote_links = 'Include Partner Libraries' != params.dig('f', 'cluster', 0)
    alma_mms_id = options[:document][:alma_mms_id]
    hathi_pd = false
    hathi_etas = nil
    ret = values.map do |value|
      JSON.parse(value).map do |link_struct|
        url = link_struct['linkurl']
        text = link_struct['linktext']
        postfix = link_struct['postfix']
        if text == @@HATHI_PD_TEXT
          hathi_pd = true
        elsif postfix == @@HATHI_ETAS_POSTFIX
          if hathi_etas.nil?
            hathi_etas = [url]
          elsif hathi_etas.include? url
            next # dedupe identical urls; infrequent, but possible
          else
            hathi_etas << url
          end
          url = @@HATHI_LOGIN_PREFIX + URI.encode_www_form_component(url)
          append = @@HATHI_INFO
        end
        %Q{<a href="#{url}"> <span class="label label-availability label-primary">Online access</span>#{text}</a>#{postfix}#{append}}
        (suppress_remote_links && text =~ /View record in .*\'s catalog/) ? nil : %Q{<a href="#{url}">#{text}</a>#{postfix}#{append}}
      end.compact.join('<br/>')
    end.reject { |item| item.blank? }.join('<br/>')
    unless alma_mms_id.nil?
      if hathi_pd
        ret = ret.concat(hathi_tag_id('pd', alma_mms_id))
      end
      if hathi_etas
        ret = ret.concat(hathi_tag_id('etas', alma_mms_id))
      end
    end
    ret.blank? ? 'Has partner library holdings' : ret.html_safe
  end

  def render_online_display_for_show_view(options)
    values = options[:value]
    alma_mms_id = options[:document][:alma_mms_id]
    hathi_pd = false
    hathi_etas = nil
    ret = values.map do |value|
      JSON.parse(value).map do |link_struct|
        url = link_struct['linkurl']
        text = link_struct['linktext']
        postfix = link_struct['postfix']
        orig_url = url
        if text == @@HATHI_PD_TEXT
          hathi_pd = true
        elsif postfix == @@HATHI_ETAS_POSTFIX
          if hathi_etas.nil?
            hathi_etas = [url]
          elsif hathi_etas.include? url
            next # dedupe identical urls; infrequent, but possible
          else
            hathi_etas << url
          end
          url = @@HATHI_LOGIN_PREFIX + URI.encode_www_form_component(url)
          append = @@HATHI_INFO
        end
        html = %Q{<div class="online-resource-link-group"><a href="#{url}">#{text}</a>#{postfix}#{append}}
        html += '<br/>'.html_safe

        if !text.start_with?('http')
          html += + orig_url
        end

        if link_struct['volumes']
          volumes_links = link_struct['volumes'].map do |link_struct2|
            url2 = link_struct2['linkurl']
            text2 = link_struct2['linktext']
            %Q{<a href="#{url2}">#{text2}</a>}
          end
          first5 = volumes_links[0,5].join(', ')
          remainder = (volumes_links[5..-1] || []).join(', ')
          remainder_count = volumes_links.size - 5

          html += '<div class="volumes-available">Volumes available: '
          html += first5
          if remainder.present?
            html += %Q{, <a class="show-online-resource-extra-links" href="">[show #{remainder_count} more]</a>}
            html += '<span class="online-resource-extra-links">'
            html += remainder
            html += '</span>'
          end
          html += '</div>'
        end

        html += '</div>'

        html
      end.compact.join
    end.join
    unless alma_mms_id.nil?
      if hathi_pd
        ret = ret.concat(hathi_tag_id('pd', alma_mms_id))
      end
      if hathi_etas
        ret = ret.concat(hathi_tag_id('etas', alma_mms_id))
      end
    end
    ret.html_safe
  end

  def hathi_tag_id(type, id)
    # TODO: remove? deprecated? I don't think anyone reads this value anymore as of now
    "<div id=\"hathi_#{type}-#{id}\" display=\"none\"></div>"
  end

  def render_web_link_display(options)
    web_link_display_values = options[:value]
    web_link_display_values.map do |web_link_display|
      if web_link_display.has_key?(:img_src)
        img = content_tag('img', '', { src: web_link_display[:img_src], alt: web_link_display[:img_alt] })
        content_tag('a', img, { href: web_link_display[:linkurl] })
      else
        content_tag('a', web_link_display[:linktext], { href: web_link_display[:linkurl] })
      end
    end.join('<br/>').html_safe
  end

  # creates a URL for the given hash record. based on 'link_type' key and other keys
  # @param record [Hash]
  # @return [String] url
  def link_for_link_type(record)
    val = record[:value_for_link] || record[:value]
    case record[:link_type]
      when 'search'
        search_catalog_path(q: val, search_field: record[:link_type])
      when /_search/
        search_catalog_path(q: val, search_field: record[:link_type])
      when /_xfacet/
        search_catalog_path(q: val, search_field: record[:link_type])
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

  # Shim between the solr-stored subject structs and `render_linked_values`, which expects
  # a different format.
  def render_linked_values_new(options)
    track_dups = Set.new
    values = []
    options[:value].each do |s|
      s = JSON.parse(s)
      val = s['val']
      val << '.' unless val.ends_with?('.')
      next unless track_dups.add?(val) # skip duplicate vals
      append = s['append']
      if s['prefix']
        # presence of a prefix indicates that the heading is browseable
        link_type = 'subject_xfacet2'
      else
        # no prefix => not browseable => use search instead (and append action for transparency)
        link_type = 'subject_search'
        append = "#{append} (search)"
      end
      values << {
        value: val.gsub('--', ' -- '), # back-compat with "spacious" delimiter display
        value_for_link: val.gsub('--', ' '), # link value for some reason omits delimiters
        value_append: append,
        link_type: link_type
      }
    end
    render_linked_values(value: values)
  end

  # 2017/06/22: This is now obsolete and unused because both subject facet
  # and xfacet values have -- separators and they don't need to be removed.
  #
  # translates the subject xfacet value to a value suitable for the linked facet field
  def subject_xfacet_to_facet(value)
    value.gsub('--', ' ').gsub(/\s{2,}/, ' ')
  end

end
