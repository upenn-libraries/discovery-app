# frozen_string_literal: true

module TurboAlmaApi
  module Bib
    # sprinkle additional and Penn-specific behavior on top of Alma::BibItem
    class PennItem < Alma::BibItem
      PICKUP_LOCATIONS = [
        ['Van Pelt Library', 'VanPeltLib'],
        ['Van Pelt Locker Pickup', 'VPLOCKER'],
        ['Annenberg Library', 'AnnenLib'],
        ['Athenaeum Library', 'AthLib'],
        ['Biotech Commons', 'BiomLib'],
        ['Chemistry Library', 'ChemLib'],
        ['Dental Medicine Library', 'DentalLib'],
        ['Dental Medicine Locker Pickup', 'DENTLOCKER'],
        ['Fisher Fine Arts Library', 'FisherFAL'],
        ['Library at the Katz Center', 'KatzLib'],
        ['Math/Physics/Astronomy Library', 'MPALib'],
        ['Museum Library', 'MuseumLib'],
        ['Ormandy Music and Media Center', 'MusicLib'],
        ['Pennsylvania Hospital Library', 'PAHospLib'],
        ['Veterinary Library - New Bolton Center', 'VetNBLib'],
        ['Veterinary Library - Penn Campus', 'VetPennLib'],
      ]

      # Rudimentary list of material types unsuitable for Scan & Deliver
      UNSCANNABLE_MATERIAL_TYPES = %w[
        RECORD DVD CDROM BLURAY BLURAYDVD LP FLOPPY_DISK DAT GLOBE
        AUDIOCASSETTE VIDEOCASSETTE HEAD LRDSC CALC KEYS RECORD
        LPTOP EQUIP OTHER AUDIOVM
      ].freeze

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
        self['bib_data'].dig field
      end

      # Determine, based on various response attributes, if this Item is
      # able to be circulated.
      # If a user cannot check out an item, the #not_loanable? call will be false and prevent requesting
      # @return [TrueClass, FalseClass]
      def checkoutable?
        in_place? &&
          # !non_circulating? &&
          !not_loanable? &&
          !aeon_requestable?
      end

      # Penn uses "Non-circ" in Alma
      def non_circulating?
        circulation_policy.include?('Non-circ')
      end

      # Is the item able to be Scan&Deliver'd?
      # @return [TrueClass, FalseClass]
      def scannable?
        aeon_requestable? || !item_data.dig('physical_material_type', 'value')
                                       .in?(UNSCANNABLE_MATERIAL_TYPES)
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
      # This is tailored to the user_id, if provided
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
        library_name == 'ZUnavailable'
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
                         location_name
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

      def pub_year
        item_data['chronology_i']
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
        if raw_policy == 'Not loanable'
          'Restricted Access'
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

      # TODO: is this right? AlmaAvailability parses availability XML and gets a location_code
      def aeon_requestable?
        aeon_site_codes = PennLib::BlacklightAlma::CodeMappingsSingleton.instance.code_mappings.aeon_site_codes
        location = if item_data.dig('location', 'value')
                     item_data['location']['value']
                   else
                     holding_data['location']['value']
                   end
        location.in? aeon_site_codes
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
          'library' => location_name,
          'due_date' => user_due_date_policy,
          'aeon_requestable' => aeon_requestable?,
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
