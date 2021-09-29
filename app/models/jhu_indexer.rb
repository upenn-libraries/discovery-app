class JhuIndexer < FranklinIndexer

  def define_record_source_id
    to_field 'record_source_id' do |rec, acc|
      acc << RecordSource::JHU
    end
  end

  def define_record_source_facet
    to_field 'record_source_f' do |rec, acc|
      acc << 'Johns Hopkins'
    end
  end

  def get_namespaced_id(rec)
    id = get_001_id(rec)
    id.blank? ? nil : "JHU_#{id}"
  end

  def link_to_source_context(rec)
    system_id = get_001_id(rec)
    "https://catalyst.library.jhu.edu/catalog/bib_#{system_id}"
  end

  def define_mms_id
    # no-op
  end

  def define_id
    to_field 'id' do |rec, acc, context|
      id = get_namespaced_id(rec)
      if id.nil?
        context.skip!('Skipping institutional record with no 001')
      end
      if rec.fields('245').empty?
        context.skip!('Skipping record with no 245; not a bib record?')
      end
      acc.replace([id])
    end
  end

  def get_001_id(rec)
    id = rec.fields('001').first&.value&.strip
    id.blank? ? nil : id
  end

  def define_grouped_id
    to_field 'grouped_id' do |rec, acc|
      oclc_ids = get_oclc_id_values(rec)
      if oclc_ids.size > 1
        puts 'Warning: Multiple OCLC IDs found, using the first one'
      end
      oclc_id = oclc_ids.first
      id = get_namespaced_id(rec)

      prefix = oclc_id.present? ? "#{oclc_id}!" : ''
      acc << "#{prefix}#{id}"
    end
  end

  def subfield_a_is_oclc(sf)
    sf.code == 'a' && sf.value =~ /^\(OCoLC(-M)?\).*/
  end

  def get_oclc_id_values(rec)
    rec.fields('035')
       .select { |f| f.any? { |sf| subfield_a_is_oclc(sf) } }
       .take(1)
       .flat_map do |field|
      field.find_all { |sf| subfield_a_is_oclc(sf) }.map do |sf|
        m = /^\s*\(OCoLC(-M)?\)[^1-9]*([1-9][0-9]*).*$/.match(sf.value)
        if m
          m[2]
        end
      end.compact
    end
  end

  def define_full_text_link_a
    to_field 'full_text_link_a' do |rec, acc|

      links = []

      links << {
        linktext: 'View record in Johns Hopkins\' catalog',
        linkurl: link_to_source_context(rec)
      }

      acc << links.to_json

    end
  end

  def get_cluster_id(rec)
    get_oclc_id_values(rec).first || begin
                                       id = get_namespaced_id(rec)
                                       digest = Digest::MD5.hexdigest(id)
                                       # first 8 hex digits = first 4 bytes. construct an int out of that hex str.
                                       digest[0,8].hex
                                     end
  end

end
