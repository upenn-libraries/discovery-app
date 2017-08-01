require 'open-uri'

module PennLib

  module LibrariesAndLocations

    class << self

      def locations(library_code)
        url = "https://api-na.hosted.exlibrisgroup.com/almaws/v1/conf/libraries/#{library_code}/locations?apikey=#{ENV['ALMA_API_KEY']}"
        doc = Nokogiri::XML(open(url))
        doc.root.children.map do |location|
          {
            code: location.children.find {|c| c.name == 'code'}.text,
            name: location.children.find {|c| c.name == 'name'}.text,
          }
        end
      end

      def libraries
        url = "https://api-na.hosted.exlibrisgroup.com/almaws/v1/conf/libraries?apikey=#{ENV['ALMA_API_KEY']}"
        doc = Nokogiri::XML(open(url))
        doc.root.children.map do |library|
          code = library.children.find {|c| c.name == 'code'}.text
          {
            code: code,
            name: library.children.find {|c| c.name == 'name'}.text,
            locations: locations(code)
          }
        end
      end

      def all_locations_hash
        libraries.flat_map do |library|
          library[:locations].map {|location| location[:name] = "#{library[:name]} - #{location[:name]}"; location}
        end.reduce(Hash.new) do |acc, item|
          acc[item[:code]] = item[:name]
          acc
        end
      end

      # outputs pipe-delimited CSV of location codes and their names in locations.xml file and ALMA.
      def compare_locations
        all_locations = all_locations_hash

        doc = Nokogiri::XML(open(Rails.root.join('config').join('translation_maps').join('locations.xml')))

        puts "code|locations.xml|ALMA"
        doc.root.children
          .select {|e| e.name == 'location'}
          .each do |location|
          code = location['location_code']
          specific_location_e = location.children.find {|e| e.name == 'specific_location'}
          if specific_location_e
            puts "#{code}|#{specific_location_e.content}|#{all_locations[code]}"
          end
        end
      end

    end

  end

end
