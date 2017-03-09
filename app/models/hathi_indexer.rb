
class HathiIndexer < FranklinIndexer

  def define_id
    to_field 'id', extract_marc('035a') do |rec, acc|
      values = acc.dup.map { |v|
        if v =~ /^sdr-zephir[0-9]*/
          'HATHI_zephir-' + v.sub(/^sdr-zephir/, '')
        elsif v =~ /^\(OCoLC\).*/
          v =~ /^\s*\(OCoLC\)[^1-9]*([1-9][0-9]*).*$/
          'HATHI_oclc-' + $1
        else
          # TODO: get id from OAI identifier element
          'HATHI_oai-' + v
        end
      }.take(1)
      acc.replace(values)
    end
  end

  def define_access_facet
    to_field "access_f_stored" do |rec, acc|
      acc << 'Online'
    end
  end

end
