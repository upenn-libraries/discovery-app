
class CrlIndexer < FranklinIndexer

  def define_id
    to_field "id", extract_marc('907a') do |rec, acc|
      acc.map! { |id| id.present? ? "CRL_#{id[2,7]}" : '' }
    end
  end

  def define_access_facet
    to_field "access_f_stored" do |rec, acc|
      acc << 'Offsite'
    end
  end

  def define_oclc_id
    to_field 'oclc_id', extract_marc('001') do |rec, acc|
      acc.map! { |id|
        if id =~ /^[^1-9]*([1-9][0-9]*).*$/
          $1
        else
          id
        end
      }
    end
  end

end
