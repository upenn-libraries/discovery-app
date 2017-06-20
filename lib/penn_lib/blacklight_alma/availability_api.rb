
require 'singleton'

module PennLib
  module BlacklightAlma

    # keeps a single copy of our mappings in memory
    class CodeMappingsSingleton
      include Singleton

      attr_reader :code_mappings

      def initialize
        @code_mappings ||= PennLib::CodeMappings.new(Rails.root.join('config').join('translation_maps'))
      end
    end

    class AvailabilityApi < ::BlacklightAlma::AvailabilityApi

      def code_mappings
        CodeMappingsSingleton.instance.code_mappings
      end

      def transform_holding(holding)
        if holding['inventory_type'] == 'physical'
          location_display_from_api = holding['location']
          loc = code_mappings.locations[holding['location_code']] || Hash.new
          holding['location'] = loc['display'] || location_display_from_api
          holding['link_to_aeon'] = code_mappings.aeon_site_codes.member?(holding['location_code'])
        end
        holding
      end

    end
  end
end
