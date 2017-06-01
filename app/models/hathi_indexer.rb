
class HathiIndexer < FranklinIndexer

  def define_all_fields
    super
    define_full_text_link_hathi
  end

  def define_mms_id
    # no-op
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
        elsif v =~ /^\(HATHI-OAI\)(.*)/
          id_from_oai = $1
          { id: id_from_oai.sub(/^.*-/, ''), type: 'oai' }
        end
      end.compact
    end
  end

  def get_hathi_id(rec)
    ids_and_types = get_ids_and_types_from_035a(rec)
    %w(zephir oai oclc).map do |type|
      ids_and_types
        .select { |id_and_type| id_and_type[:type] == type && id_and_type[:id].present? }
        .map { |id_and_type| "HATHI_#{type}-" + id_and_type[:id] }
        .first
    end.compact.first
  end

  def define_id
    to_field 'id' do |rec, acc, context|
      hathi_id = get_hathi_id(rec)

      if !hathi_id.present?
        context.skip!("Warning: skipping Hathi record with no ID (035a)")
      end

      acc.replace([ hathi_id ])
    end
  end

  def define_grouped_id
    to_field 'grouped_id' do |rec, acc|
      oclc_ids = pennlibmarc.get_oclc_id_values(rec)
      if oclc_ids.size > 1
        puts 'Warning: Multiple OCLC IDs found, using the first one'
      end
      oclc_id = oclc_ids.first
      hathi_id = get_hathi_id(rec)

      prefix = oclc_id.present? ? "#{oclc_id}!" : ''
      acc << "#{prefix}#{hathi_id}"
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

      acc.concat(pennlibmarc.get_full_text_link_values(rec))

      # this section is equivalent to the hathi-link XSL function

      ids_and_types = get_ids_and_types_from_035a(rec)
      id_and_type = ids_and_types.first

      links = rec.fields('856').map do |field|
        pennlibmarc.linktext_and_url(field)
      end
      links_html = links.map do |link_struct|
        url = link_struct[1]
        text = link_struct[0].present? ? link_struct[0] : url
        %Q{<a href="#{url}">#{text}</a>}
      end

      first5 = links_html[0,5].join(', ')
      remainder = (links_html[5..-1] || []).join(', ')
      remainder_count = links_html.size - 5

      url = hathi_link(id_and_type[:id], id_and_type[:type])
      html = %Q{<a href="#{url}" class="hathi_dynamic">HathiTrust Digital Library Connect to full text</a>}
      html += '<div class="hathi_dynamic">Volumes available: '
      html += first5
      if remainder.present?
        html += %Q{, <a class="show_hathi_extra_links" href="">[show #{remainder_count} more]</a>}
        html += '<span class="hathi_extra_links">'
        html += remainder
        html += '</span>'
      end
      html += '</div>'

      acc << html

      # deal with Hathi full text links that don't have Hathi in link text

      more_links = rec.fields('856')
                       .select { |f| f.indicator1 == '4' && %w(0 1).member?(f.indicator2) }
                       .map do |field|
        pennlibmarc.linktext_and_url(field)
      end
      # TODO: this condition should be false most of the time, but instead it's true WHY????
      if !more_links.select { |link_struct| link_struct[0] =~ /[Hh]athi/ }.present?
        oclc_id = ids_and_types.select { |v| v[:type] == 'oclc' }.map { |v| v[:id] }.first
        acc <<  %Q{<a href="#{"http://catalog.hathitrust.org/api/volumes/oclc/#{oclc_id}.html"}" class="hathi_dynamic">HathiTrust Digital Library Connect to full text</a>}
      end
    end
  end

  def define_record_source_id
    to_field 'record_source_id' do |rec, acc|
      acc << RecordSource::HATHI
    end
  end

  def define_record_source_facet
    to_field 'record_source_f' do |rec, acc|
      acc << 'Hathi'
    end
  end

  def get_cluster_id(rec)
    pennlibmarc.get_oclc_id_values(rec).first || begin
      id = get_hathi_id(rec)
      digest = Digest::MD5.hexdigest(id)
      # first 8 hex digits = first 4 bytes. construct an int out of that hex str.
      digest[0,8].hex
    end
  end

  def define_cluster_fields
    to_field 'cluster_id' do |rec, acc|
      acc << get_cluster_id(rec)
    end
  end

end
