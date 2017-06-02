
class HathiIndexer < FranklinIndexer

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

  def get_preferred_id_and_type(rec)
    ids_and_types = get_ids_and_types_from_035a(rec)
    %w(zephir oai oclc).map do |type|
      ids_and_types
        .select { |id_and_type| id_and_type[:type] == type && id_and_type[:id].present? }
        .first
    end.compact.first
  end

  def get_hathi_id(rec)
    id_and_type = get_preferred_id_and_type(rec)
    "HATHI_#{id_and_type[:type]}-#{id_and_type[:id]}"
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

  def define_full_text_link_text_a
    to_field 'full_text_link_text_a' do |rec, acc|

      links = []

      result = pennlibmarc.get_full_text_link_values(rec)
      if result.present?
        acc << result.to_json
      end

      # this section is equivalent to the hathi-link XSL function

      id_and_type = get_preferred_id_and_type(rec)

      volumes_links = rec.fields('856').map do |field|
        link_struct = pennlibmarc.linktext_and_url(field)
        url = link_struct[1]
        text = link_struct[0].present? ? link_struct[0] : url
        {
          linktext: text,
          linkurl: url,
        }
      end.sort { |x,y| x[:linktext] <=> y[:linktext] }

      links << {
        linktext: 'HathiTrust Digital Library Connect to full text',
        linkurl: hathi_link(id_and_type[:id], id_and_type[:type]),
        volumes: volumes_links,
      }

      acc << links.to_json

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

end
