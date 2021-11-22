class PennIndexer < FranklinIndexer

  # TODO: ugh, why isn't there a copyfield?
  def define_access_facet
    to_field "access_f" do |rec, acc|
      acc << if is_online_resource?(rec)
               'Online'
             else
               'At the library'
             end
    end
    to_field "access_f_stored" do |rec, acc|
      acc << if is_online_resource?(rec)
               'Online'
             else
               'At the library'
             end
    end
  end

  def is_online_resource?(rec)
    data_elements = rec['008'].value
    return false unless data_elements

    form_field = if map_or_audiorec?(rec)
                   data_elements[29]
                 else
                   data_elements[23]
                 end

    form_field&.in? %w[o q s]
  end

  # consider elements 6 and 7? to determine whether something is a "Map" or an "Audio Recording" - for the purpose of
  # then checking the appropriate 008 field for the format
  # @param [MARC::Record] rec
  # @return [TrueClass, FalseClass]
  def map_or_audiorec?(rec)
    format_code = @pennlibmarc.get_format_from_leader(rec)

    # first element only?
    format_code[0].in? %w[e i j]

    # consider both?
    # format_code.in? %w[]
  end

  def define_record_source_id
    to_field 'record_source_id' do |rec, acc|
      acc << RecordSource::PENN
    end
  end

  def define_record_source_facet
    to_field 'record_source_f' do |rec, acc|
      acc << 'Penn'
    end
  end

  def get_namespaced_id(rec)
    id = get_001_id(rec)
    id.blank? ? nil : "PENN_#{id}"
  end

  def define_id
    to_field 'id' do |rec, acc, context|
      id = get_namespaced_id(rec)
      if id.nil?
        context.skip!('Skipping institutional record with no 001')
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
      oclc_ids = pennlibmarc.get_oclc_id_values(rec)
      if oclc_ids.size > 1
        puts 'Warning: Multiple OCLC IDs found, using the first one'
      end
      oclc_id = oclc_ids.first
      id = get_namespaced_id(rec)

      prefix = oclc_id.present? ? "#{oclc_id}!" : ''
      acc << "#{prefix}#{id}"
    end
  end

  def get_cluster_id(rec)
    pennlibmarc.get_oclc_id_values(rec).first || begin
                                                   id = get_namespaced_id(rec)
                                                   digest = Digest::MD5.hexdigest(id)
                                                   # first 8 hex digits = first 4 bytes. construct an int out of that hex str.
                                                   digest[0,8].hex
                                                 end
  end

end
