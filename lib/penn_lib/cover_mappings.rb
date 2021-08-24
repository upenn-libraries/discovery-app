require 'rocksdb'

module PennLib

  module CoverMappings

    PADDING = lambda {
      raise "system must be little-endian" unless [1].pack('Q') == [1].pack('Q<')
      pad_char = "\x00"
      pad_str = ''
      map = {}
      idx = 0
      loop do
        map[idx] = pad_str
        return map if idx == 8
        idx = idx + 1
        pad_str += pad_char
      end
    }.call.freeze
    private_constant :PADDING

    def self.encode(int)
      str = [int].pack('Q')
      raise "unexpected bytesize" unless str.bytesize == 8
      idx = 7 # start at the last byte
      loop do
        return str.byteslice(0..idx) if str.getbyte(idx) != 0
        return '' if idx == 0
        idx = idx - 1
      end
    end

    # NOTE: the input string will be padded out to 8 bytes
    def self.decode!(str)
      encoded_size = str.bytesize
      if encoded_size < 8
        str = str.concat(PADDING[8 - encoded_size])
      else
        raise "too many bytes!" unless encoded_size == 8
      end
      str.unpack('Q')[0]
    end

    build_db = lambda { |file, key_transform|
      db_file = "#{file}.db"
      return RocksDB.open_readonly(db_file) if File.directory?(db_file)
      hash = RocksDB.open(db_file)
      ct = 0
      Zlib::GzipReader.new(File.open(file), :external_encoding => 'UTF-8').each_line do |line|
        keys = line.split(' ')
        target = Integer(keys.shift) rescue next
	if (ct = ct + 1) % 100000 == 0
	  puts "#{file}: #{ct}"
	end
        keys.each do |key|
          transformed_key = key_transform.call(key)
          hash[encode(transformed_key)] = encode(target) unless transformed_key.nil?
        end
      end
      hash.close
      RocksDB.open_readonly(db_file)
    }

    STRICT_INT_TRANSFORM = lambda { |id, base=10| Integer(id, base) rescue nil }
    private_constant :STRICT_INT_TRANSFORM

    strict_isbn_transform = lambda { |expect_size|
      lambda { |id|
        return nil unless expect_size.nil? || id.size == expect_size
        id.gsub!(/^0+/, '')
	# to accommodate X check digit, we treat all isbns as base-11
	id[-1] = 'a' if id.end_with?('X')
        STRICT_INT_TRANSFORM.call(id, 11)
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
      # lenient in the sense that we sanitize the isbn first, and
      # don't require a specific length
      STRICT_ISBN_TRANSFORM.call(SANITIZE_ISBN.call(id))
    }
    private_constant :LENIENT_ISBN_TRANSFORM

    OCLC_MAP = build_db.call('oclc_numbers_cover_mappings.txt.gz', STRICT_INT_TRANSFORM).freeze
    private_constant :OCLC_MAP

    ISBN10_MAP = build_db.call('isbn_10_cover_mappings.txt.gz', STRICT_ISBN10_TRANSFORM).freeze
    private_constant :ISBN10_MAP

    ISBN13_MAP = build_db.call('isbn_13_cover_mappings.txt.gz', STRICT_ISBN13_TRANSFORM).freeze
    private_constant :ISBN13_MAP

    def self.map(oclc_id, isbn10, isbn13)
      (oclc_id && from_oclc_id(oclc_id)) || (isbn10 && from_isbn_10(isbn10)) || (isbn13 && from_isbn_13(isbn13)) || nil
    end

    def self.map(oclc_id, isbns)
      unless oclc_id.nil?
        ret = from_oclc_id(oclc_id)
	return ret unless ret.nil?
      end
      return nil if isbns.blank?
      ret = nil
      isbns.find do |isbn|
        isbn = SANITIZE_ISBN.call(isbn)
        int_id = STRICT_ISBN_TRANSFORM.call(isbn)
	return nil if int_id.nil?
	encoded = encode(int_id)
        if isbn.length <= 10
          ret = ISBN10_MAP[encoded]
        elsif isbn.length <= 13
          ret = ISBN13_MAP[encoded]
        end
      end
      ret.nil? ? nil : decode!(ret)
    end

    def self.from_oclc_id(id)
      int_id = STRICT_INT_TRANSFORM.call(id)
      return nil if int_id.nil?
      ret = OCLC_MAP[encode(int_id)]
      ret.nil? ? nil : decode!(ret)
    end

    def self.from_isbn_10(id)
      int_id = LENIENT_ISBN_TRANSFORM.call(id)
      return nil if int_id.nil?
      ret = ISBN10_MAP[encode(int_id)]
      ret.nil? ? nil : decode!(ret)
    end

    def self.from_isbn_13(id)
      int_id = LENIENT_ISBN_TRANSFORM.call(id)
      return nil if int_id.nil?
      ret = ISBN13_MAP[encode(int_id)]
      ret.nil? ? nil : decode!(ret)
    end

  end

end
