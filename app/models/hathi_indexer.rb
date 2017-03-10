
class HathiIndexer < FranklinIndexer

  def define_all_fields
    super
    define_full_text_link_hathi
  end

  def get_ids_and_types_from_035a(rec)
    rec.fields('035').flat_map do |field|
      field.find_all { |sf| sf.code == 'a' }.map do |sf|
        v = sf.value
        if v =~ /^sdr-zephir[0-9]*/
          { id: v.sub(/^sdr-zephir/, ''), type: 'zephir' }
        elsif v =~ /^\(OCoLC\).*/
          v =~ /^\s*\(OCoLC\)[^1-9]*([1-9][0-9]*).*$/
          { id: $1, type: 'oclc' }
        else
          # TODO: get id from OAI identifier element
          { id: v, type: 'oai' }
        end
      end
    end
  end

  def define_id
    to_field 'id' do |rec, acc|
      id_and_type = get_ids_and_types_from_035a(rec).first
      id = id_and_type[:id]
      type = id_and_type[:type]
      hathi_id = case type
        when 'zephir'
          'HATHI_zephir-' + id
        when 'oai'
          'HATHI_oai-' + id
        when 'oclc'
          'HATHI_oclc-' + id
        else
          'HATHI_'
      end
      acc.replace([ hathi_id ])
    end
  end

  def define_access_facet
    to_field "access_f_stored" do |rec, acc|
      acc << 'Online'
    end
  end

  def hathi_link(id, type)
    url = case type
            when 'oclc'
              'http://catalog.hathitrust.org/api/volumes/oclc/'
            else
              'http://catalog.hathitrust.org/Record/'
          end
    suffix = type == 'oclc' ? '.html' : ''
    [url, id, suffix].join
  end

  def define_full_text_link_hathi
    to_field 'full_text_link_a' do |rec, acc|
      id_and_type = get_ids_and_types_from_035a(rec).first
      url = hathi_link(id_and_type[:id], id_and_type[:type])

      links = rec.fields('856').map do |field|
        pennlibmarc.linktext_and_url(field)
      end
      links_html = links.map do |link_struct|
        url = link_struct[0]
        text = link_struct[1] || url
        %Q{<a href="#{url}">#{text}</a>}
      end

      first5 = links_html[0,5].join(', ')
      remainder = links_html[5..-1].join(', ')
      remainder_count = links_html.size - 5

      html = %Q{<a href="#{url}" class="hathi_dynamic">HathiTrust Digital Library Connect to full text</a>}
      html += '<div class="hathi_dynamic">Volumes available: '
      html += first5
      if remainder.present?
        html += %Q{, <a id="hathi_show_extra_links" href="">[show #{remainder_count} more]</a>}
        html += '<span class="hathi_extra_links">'
        html += remainder
        html += '</span>'
      end
      html += '</div>'
      acc << html
    end
  end

end
