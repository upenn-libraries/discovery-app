
module PennLib

  module CoverMappings

    blah = lambda { |file, key_transform|
      hash = {}
      Zlib::GzipReader.new(File.open(file), :external_encoding => 'UTF-8').each_line { |line|
        keys = line.split(' ')
        target = Integer(keys.shift) rescue next
        keys.each do |key|
          transformed_key = key_transform.call(key)
          hash[transformed_key] = target unless transformed_key.nil?
        end
      }
      hash
    }

    STRICT_INT_TRANSFORM = lambda { |id| Integer(id) rescue nil }
    private_contstant :STRICT_INT_TRANSFORM

    STRICT_ISBN_TRANSFORM = lambda { |in|
      return STRICT_INT_TRANSFORM.call(in) unless in.end_with?('X')
      positive = STRICT_INT_TRANSFORM.call(in.chomp('X'))
      positive.nil? ? nil : -positive
    }
    private_constant :STRICT_ISBN_TRANSFORM

    SANITIZE_ISBN = lambda { |in|
      in[-1] = 'X' if in.end_with?('x')
      in.gsub(/[^0-9X]/, '')
    }
    private_constant :SANITIZE_ISBN

    LENIENT_ISBN_TRANSFORM = { |in|
      STRICT_ISBN_TRANSFORM.call(SANITIZE_ISBN.call(in))
    }
    private_constant :LENIENT_ISBN_TRANSFORM

    OCLC_MAP = blah.call('oclc_numbers_cover_mappings.txt.gz', STRICT_INT_TRANSFORM).freeze
    private_constant :OCLC_MAP

    ISBN10_MAP = blah.call('isbn_10_cover_mappings.txt.gz', STRICT_ISBN_TRANSFORM).freeze
    private_constant :ISBN10_MAP

    ISBN13_MAP = blah.call('isbn_13_cover_mappings.txt.gz', STRICT_ISBN_TRANSFORM).freeze
    private_constant :ISBN13_MAP

    def self.map(oclc_id, isbn10, isbn13)
      (oclc_id && self.from_oclc_id(oclc_id)) || (isbn10 && self.from_isbn_10(isbn10)) || (isbn13 && self.from_isbn_13(isbn13)) || nil
    end

    def self.map(oclc_id, isbn)
      if oclc_id
        ret = self.from_oclc_id(oclc_id)
	return ret unless ret.nil?
      end
      isbn = SANITIZE_ISBN.call(isbn)
      case isbn.length
      when 10
        return ISBN10_MAP[STRICT_ISBN_TRANSFORM.call(isbn)]
      when 13
        return ISBN13_MAP[STRICT_ISBN_TRANSFORM.call(isbn)]
      end
      nil
    end

    def self.from_oclc_id(id)
      OCLC_MAP[STRICT_INT_TRANSFORM.call(id)]
    end

    def self.from_isbn_10(id)
      ISBN10_MAP[LENIENT_ISBN_TRANSFORM.call(id)]
    end

    def self.from_isbn_13(id)
      ISBN13_MAP[LENIENT_ISBN_TRANSFORM.call(id)]
    end

  end

end
