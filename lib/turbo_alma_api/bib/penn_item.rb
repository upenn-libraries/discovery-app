# frozen_string_literal: true

module TurboAlmaApi
  module Bib
    # sprinkle additional and Penn-specific behavior on top of Alma::BibItem
    class PennItem < Alma::BibItem
      ETAS_TEMPORARY_LOCATION_CODE = 'vanpNocirc'
      IN_HOUSE_POLICY_CODE = 'InHouseView'
      # Rudimentary list of material types unsuitable for Scan & Deliver
      UNSCANNABLE_MATERIAL_TYPES = %w[
        RECORD DVD CDROM BLURAY BLURAYDVD LP FLOPPY_DISK DAT GLOBE
        AUDIOCASSETTE VIDEOCASSETTE HEAD LRDSC CALC KEYS RECORD
        LPTOP EQUIP OTHER AUDIOVM
      ].freeze
      UNAVAILABLE_LIBRARY_CODE = 'ZUnavailable'

      # Is this Item restricted from circulation due to ETAS?
      # @return [TrueClass, FalseClass]
      def etas_restricted?
        temp_location == ETAS_TEMPORARY_LOCATION_CODE
      end

      # overrides to also check holding data since we have so many "no item" cases....
      def holding_library
        item_data.dig('library', 'value') || holding_data.dig('library', 'value')
      end

      def holding_library_name
        item_data.dig('library', 'desc') || holding_data.dig('library', 'desc')
      end

      def holding_location
        item_data.dig('location', 'value') || holding_data.dig('location', 'value')
      end

      def holding_location_name
        item_data.dig('location', 'desc') || holding_data.dig('location', 'desc')
      end
      # end overrides

      def identifiers
        { item_pid: pid,
          holding_id: holding_data['holding_id'],
          mms_id: self['bib_data']['mms_id'] }
      end

      # @return [String]
      def pid
        item_data.dig 'pid'
      end

      # @return [String]
      def holding_id
        holding_data['holding_id']
      end

      # @return [String]
      def bib(field)
        self['bib_data']&.dig field
      end

      def barcode
        item_data.dig 'barcode'
      end

      # Determine, based on various response attributes, if this Item is
      # able to be circulated.
      # If a user cannot check out an item, the #not_loanable? call will be false and prevent requesting
      # @return [TrueClass, FalseClass]
      def checkoutable?
        in_place? &&
          !not_loanable? &&
          !aeon_requestable? &&
          !on_reserve? &&
          !at_reference? &&
          !in_house_use_only? &&
          !etas_restricted?
      end

      # Penn uses "Non-circ" in Alma
      # @return [TrueClass, FalseClass]
      def non_circulating?
        circulation_policy.include?('Non-circ')
      end

      # Is the item able to be Scan&Deliver'd?
      # @return [TrueClass, FalseClass]
      def scannable?
        return false if at_hsp?

        aeon_requestable? ||
          !item_data.dig('physical_material_type', 'value').in?(UNSCANNABLE_MATERIAL_TYPES)
      end

      def temp_aware_location_display
        if in_temp_location?
          return "(temp) #{holding_data.dig('temp_library', 'value')} - #{holding_data.dig('temp_location', 'value')}"
        end

        "#{holding_library_name} - #{holding_location_name}"
      end

      def temp_aware_call_number
        temp_call_num = holding_data.dig('temp_call_number')
        return temp_call_num if temp_call_num.present?

        holding_data.dig('permanent_call_number')
      end

      # @return [String]
      def user_due_date
        item_data.dig 'due_date'
      end

      # @return [String]
      def user_due_date_policy
        item_data.dig 'due_date_policy'
      end

      # @return [TrueClass, FalseClass]
      def in_house_use_only?
        item_data.dig('policy', 'value') == IN_HOUSE_POLICY_CODE ||
          holding_data.dig('temp_policy', 'value') == IN_HOUSE_POLICY_CODE
      end

      # This is tailored to the user_id, if provided
      # @return [TrueClass, FalseClass]
      def not_loanable?
        user_due_date_policy&.include? 'Not loanable'
      end

      # is the holding flagged for suppression from publishing?
      # @return [TrueClass, FalseClass]
      def suppressed?
        holding_data.dig('holding_suppress_from_publishing') == 'true'
      end

      # Is this Item in the mythical "Unavailable" Library? Apparently, a graveyard for withdrawn Items
      # @return [TrueClass, FalseClass]
      def in_unavailable_library?
        library == UNAVAILABLE_LIBRARY_CODE
      end

      # Does the holding have temporary location or library information?
      def in_temp_location?
        holding_data.dig 'in_temp_location' == 'true'
      end

      # Whether or not this Item should hidden from display in a Patron context
      # @return [TrueClass, FalseClass]
      def hide_from_patrons?
        suppressed? ||
          in_unavailable_library?
      end

      # Label text for select2
      # TODO: rename to to_s
      # @return [String]
      def label_for_select
        label_info = if item_data.present?
                       [
                         description,
                         physical_material_type['desc'],
                         public_note,
                         user_policy_display(user_due_date_policy),
                         library_name
                       ]
                     else # no item data case - holding as item...
                       [
                         'Restricted Access',
                         holding_data['location']['desc']
                       ]
                     end
        label_info.reject(&:blank?).join(' - ')
      end

      def volume
        item_data['enumeration_a']
      end

      def issue
        item_data['enumeration_b']
      end

      # get raw year of publication, preferring value from Item over Bib
      def pub_year
        pub_year = item_data['chronology_i'].presence || bib('date_of_publication').presence
        pub_year&.gsub(/\D/, '')
      end

      def pub_month
        item_data['chronology_j']
      end

      # TODO: improve these
      def improved_description
        og_description = description
        og_description
          .sub('v.', 'Volume ')
          .sub('no.', 'Number ')
          .sub('pt.', 'Part ')
      end

      # @param [String] raw_policy
      def user_policy_display(raw_policy)
        if (raw_policy == 'Not loanable') && !restricted_circ?
          'Restricted Access'
        elsif on_reserve?
          'On Reserve'
        elsif at_reference?
          'At Reference Desk'
        elsif in_house_use_only?
          'On Site Use Only'
        elsif !checkoutable?
          'Currently Unavailable'
        else
          case raw_policy
          when 'End of Year'
            'Return by End of Year'
          when 'End of Term'
            'Return by End of Term'
          else
            raw_policy
          end
        end
      end

      # @return [TrueClass, FalseClass]
     def aeon_requestable?
        aeon_site_codes = PennLib::BlacklightAlma::CodeMappingsSingleton.instance.code_mappings.aeon_site_codes
        location = if item_data.dig('location', 'value')
                     item_data['location']['value']
                   else
                     holding_data['location']['value']
                   end
        location.in? aeon_site_codes
      end

      # @return [TrueClass, FalseClass]
      def on_reserve?
        item_data.dig('policy', 'value') == 'reserve' ||
        holding_data.dig('temp_policy', 'value') == 'reserve'
      end

      # @return [TrueClass, FalseClass]
      def at_reference?
        item_data.dig('policy', 'value') == 'reference' ||
          holding_data.dig('temp_policy', 'value') == 'reference'
      end

      # @return [TrueClass, FalseClass]
      def at_archives?
        library_name == 'University Archives'
      end

      # Is the item a Historical Society of Pennsylvania record? If so, it cannot be requested.
      # @return [TrueClass, FalseClass]
      def at_hsp?
        library == 'HSPLib'
      end
      
      # @return [TrueClass, FalseClass]
      def restricted_circ?
        on_reserve? || at_reference? || in_house_use_only? || at_hsp?
      end

      def isxn
        bib('issn') || bib('isbn')
      end

      # TODO: use to_h here?
      def for_select(_options = {})
        {
          'id' => item_data.dig('pid') || 'no-item',
          'text' => label_for_select,
          'title' => self['bib_data']['title'],
          'description' => description,
          'public_note' => public_note,
          'holding_id' => holding_data['holding_id'],
          'circulate' => checkoutable?,
          'call_number' => call_number,
          'location' => location_name,
          'library' => library_name,
          'due_date' => user_due_date_policy,
          'aeon_requestable' => aeon_requestable?,
          'on_reserve' => on_reserve?,
          'at_reference' => at_reference?,
          'at_hsp' => at_hsp?,
          'at_archives' => at_archives?,
          'in_house_only' => in_house_use_only?,
          'restricted_circ' => restricted_circ?,
          'volume' => volume,
          'issue' => issue,
          'isxn' => isxn,
          'in_place' => in_place?,
          'scannable' => scannable?
        }
      end
    end
  end
end
