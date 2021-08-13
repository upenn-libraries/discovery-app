
module PennLib

  module CoverMappings

    blah = lambda { |file, key_transform|
      hash = {}
      return hash unless File.file?(file)
      ct = 0
      Zlib::GzipReader.new(File.open(file), :external_encoding => 'UTF-8').each_line do |line|
        keys = line.split(' ')
        target = Integer(keys.shift) rescue next
	if (ct = ct + 1) % 100000 == 0
	  puts "#{file}: #{ct}"
	end
        keys.each do |key|
          transformed_key = key_transform.call(key)
          hash[transformed_key] = target unless transformed_key.nil?
        end
      end
      hash
    }

    STRICT_INT_TRANSFORM = lambda { |id| Integer(id) rescue nil }
    private_constant :STRICT_INT_TRANSFORM

    strict_isbn_transform = lambda { |expect_size|
      lambda { |id|
        return nil unless expect_size.nil? || id.size == expect_size
        id.gsub!(/^0+/, '')
        return STRICT_INT_TRANSFORM.call(id) unless id.end_with?('X')
        positive = STRICT_INT_TRANSFORM.call(id[0..-2])
        positive.nil? ? nil : -positive
      }
    }

    STRICT_ISBN_TRANSFORM = strict_isbn_transform.call(nil)
    private_constant :STRICT_ISBN_TRANSFORM
    STRICT_ISBN10_TRANSFORM = strict_isbn_transform.call(10)
    private_constant :STRICT_ISBN10_TRANSFORM
    STRICT_ISBN13_TRANSFORM = strict_isbn_transform.call(13)
    private_constant :STRICT_ISBN13_TRANSFORM

    SANITIZE_ISBN = lambda { |id|
      id.gsub!(/[^0-9Xx]/, '')
      id[-1] = 'X' if id.end_with?('x')
      id
    }
    private_constant :SANITIZE_ISBN

    LENIENT_ISBN_TRANSFORM = lambda { |id|
      STRICT_ISBN10_TRANSFORM.call(SANITIZE_ISBN.call(id))
    }
    private_constant :LENIENT_ISBN_TRANSFORM

    OCLC_MAP = blah.call('oclc_numbers_cover_mappings.txt.gz', STRICT_INT_TRANSFORM).freeze
    private_constant :OCLC_MAP

    ISBN10_MAP = blah.call('isbn_10_cover_mappings.txt.gz', STRICT_ISBN10_TRANSFORM).freeze
    private_constant :ISBN10_MAP

    ISBN13_MAP = blah.call('isbn_13_cover_mappings.txt.gz', STRICT_ISBN13_TRANSFORM).freeze
    private_constant :ISBN13_MAP

    def self.map(oclc_id, isbn10, isbn13)
      (oclc_id && self.from_oclc_id(oclc_id)) || (isbn10 && self.from_isbn_10(isbn10)) || (isbn13 && self.from_isbn_13(isbn13)) || nil
    end

    def self.map(oclc_id, isbns)
      unless oclc_id.nil?
        ret = self.from_oclc_id(oclc_id)
	return ret unless ret.nil?
      end
      return nil if isbns.blank?
      ret = nil
      isbns.find do |isbn|
        isbn = SANITIZE_ISBN.call(isbn)
        if isbn.length <= 10
          ret = ISBN10_MAP[STRICT_ISBN_TRANSFORM.call(isbn)]
        elsif isbn.length <= 13
          ret = ISBN13_MAP[STRICT_ISBN_TRANSFORM.call(isbn)]
        else
          nil
        end
      end
      ret
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
