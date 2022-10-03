
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

      # As of July 2018, the Alma API we are using to retrieve availability
      # information exhibits inconsistent behavior with respect to retrieving
      # holdings for related records. To handle these cases, we retrieve
      # holdings for the main MMSID and all related boundwith MMSIDs and filter
      # out holdings where the holding MMSID does not match the bib MMSID,
      # preventing a holding from displaying more than once.
      def parse_bibs_data(api_response)
        super.each do |mmsid, values|
          values['holdings'].select! do |hld|
            hld['inventory_type'] != 'physical' || hld['mmsid'] == mmsid || !hld.key?('mmsid')
          end
        end
      end

      # TODO: Move into blacklight_alma gem?
      def get_availability(id_list)
        api_params = {
            'mms_id' => id_list.map(&:to_s).map(&:strip).join(','),
            'expand' => 'p_avail,e_avail,d_avail,requests'
        }

        api_response = ::BlacklightAlma::BibsApi.instance.get_availability(api_params)

        if api_response
          web_service_result = api_response['web_service_result']
          if !web_service_result
            begin
              availability = parse_bibs_data(api_response)
            rescue Exception => e
              Blacklight.logger.error("Error parsing ALMA response: #{e}, response data=#{api_response}")
            end
            response_data = {
                'availability' => availability
            }
          else
            # Errors look like this:
            # { "web_service_result"=>
            #   { "errorsExist"=>"true",
            #     "errorList"=>
            #       {"error"=>
            #         {"errorCode"=>"INTERNAL_SERVER_ERROR",
            #          "errorMessage"=>"\nThe web server encountered an unexpected condition that prevented it from fulfilling the request. If the error persists, please use the unique tracking ID when reporting it.",
            #          "trackingId"=>"..."
            #         }
            #       }
            #   }
            # }
            Blacklight.logger.error("ALMA JSON response contains error code=#{api_response}")
            response_data = {
              # not clear why it's called 'errorList', could value be an array sometimes? not sure.
              # for this reason, we pass it wholesale.
                'error' => web_service_result['errorList'].present? ? web_service_result['errorList'] : 'Unknown error from ALMA API'
            }
          end
        else
          response_data = {
              'error' => 'Error making request to ALMA, received no data in response'
          }
        end
        response_data
      end

      # TODO: Move into blacklight_alma gem?
      # @return [Hash] data structure describing holdings of bib ids
      def parse_bibs_data(api_response)
        # make sure bibs is always an Array
        bibs = [ api_response['bibs']['bib'] ].flatten(1)

        inventory_types = ::BlacklightAlma::AvailabilityApi.inventory_type_to_subfield_codes_to_fieldnames.keys

        bibs.map do |bib|
          record = Hash.new
          record['mms_id'] = bib['mms_id']
          record['requests'] = bib['requests']['__content__']

          inventory_fields = bib.fetch('record', Hash.new).fetch('datafield', []).select { |df| inventory_types.member?(df['tag']) } || []

          record['holdings'] = inventory_fields.map do |inventory_field|
            inventory_type = inventory_field['tag']
            subfield_codes_to_fieldnames = ::BlacklightAlma::AvailabilityApi.inventory_type_to_subfield_codes_to_fieldnames[inventory_type]

            # make sure subfields is always an Array (which isn't the case if there's only one subfield element)
            subfields = [ inventory_field.fetch('subfield', []) ].flatten(1)

            holding = subfields.reduce(Hash.new) do |acc, subfield|
              fieldname = subfield_codes_to_fieldnames[subfield['code']]
              fieldvalue = subfield['__content__']
              if acc[fieldname].present?
                # value already set - concat! but only if not falsey
                acc[fieldname] = acc[fieldname] + fieldvalue if fieldvalue
              else
                acc[fieldname] = fieldvalue
              end
              acc
            end
            holding['inventory_type'] = subfield_codes_to_fieldnames['INVENTORY_TYPE']
            holding = transform_holding(holding)
            holding
          end
          record
        end.reduce(Hash.new) do |acc, avail|
          acc[avail['mms_id']] = avail.select { |k,v| k != 'mms_id' }
          acc
        end
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
