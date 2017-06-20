
module PennLib

  # This class manages access to the mappings files for various types of codes
  # (locations, relator codes, languages, classification codes).
  # It caches values in memory.
  class CodeMappings

    attr_accessor :path_to_lookup_files

    def initialize(path_to_lookup_files)
      @path_to_lookup_files = path_to_lookup_files
    end

    # block should return a hash to be merged into the hash that we're building
    def load_xml_lookup_file(filename, xpath_expr, &block)
      lookup = {}
      doc = Nokogiri::XML(File.open(Pathname.new(path_to_lookup_files) + filename))
      doc.xpath(xpath_expr).each do |element|
        lookup.merge! block.call(element)
      end
      lookup
    end

    def relator_codes
      @relator_codes ||= load_xml_lookup_file('relatorcodes.xml', '/relatorcodes/relator') do |element|
        { element['code'] => element.text }
      end
    end

    def locations
      @locations ||= load_xml_lookup_file('locations.xml', '/locations/location') do |element|
        struct = element.element_children.map { |c| [c.name, c.text] }.reduce(Hash.new) do |acc, rec|
          value = rec[1]
          # 'library' is multivalued
          if rec[0] == 'library'
            value = (acc[rec[0]] || Array.new)
            value << rec[1]
          end
          acc[rec[0]] = value
          acc
        end
        { element['location_code'] =>  struct }
      end
    end

    def loc_classifications
      @loc_classifications ||= load_xml_lookup_file('ClassOutline.xml', '/list/class') do |element|
        { element['value'] => element.text }
      end
    end

    def dewey_classifications
      @dewey_classifications ||= load_xml_lookup_file('DeweyClass.xml', '/list/class') do |element|
        { element['value'] => element.text }
      end
    end

    def languages
      @languages ||= load_xml_lookup_file('languages2.xml', '/languages/lang') do |element|
        { element['code'] => element.text }
      end
    end

    def aeon_site_codes
      @aeon_site_codes = File.readlines(Pathname.new(path_to_lookup_files) + 'aeonSiteCodes.txt').map(&:strip)
    end

  end

end
