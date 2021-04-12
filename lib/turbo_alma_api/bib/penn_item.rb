# frozen_string_literal: true

module TurboAlmaApi
  module Bib
    # sprinkle additional and Penn-specific behavior on top of Alma::BibItem
    class PennItem < Alma::BibItem
      ETAS_TEMPORARY_LOCATION = 'ETAS No Loans No Requests'

      def identifiers
        { item_pid: pid,
          holding_id: holding_data['holding_id'],
          mms_id: self['bib_data']['mms_id'] }
      end

      # @return [String]
      def pid
        item_data.dig 'pid'
      end

      # @return [Hash]
      def bib(field)
        self['bib_data'].dig field
      end

      # Determine, based on various response attributes, if this Item is
      # able to be circulated.
      # @return [TrueClass, FalseClass]
      def checkoutable?
        in_place? &&
          !non_circulating? &&
          !etas_restricted? &&
          !not_loanable? &&
          !aeon_requestable?
      end

      # Penn uses "Non-circ" in Alma
      def non_circulating?
        circulation_policy.include?('Non-circ')
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
      def not_loanable?
        user_due_date_policy&.include? 'Not loanable'
      end

      # Is this Item restricted from circulation due to ETAS?
      # @return [TrueClass, FalseClass]
      def etas_restricted?
        # is in ETAS temporary location?
        temp_location_name == ETAS_TEMPORARY_LOCATION
      end

      # Label text for Item radio button
      # @return [String]
      def label_for_radio_button
        label_info = [
          location_name,
          description,
          user_policy_display(user_due_date_policy)
        ]
        label_info.reject(&:blank?).join(' - ')
      end

      # Label text for Item radio button
      # @return [String]
      def label_for_select
        label_info = [
          description,
          physical_material_type['desc'],
          public_note,
          user_policy_display(user_due_date_policy),
          location_name,
        ]
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
        case raw_policy
        when 'Not loanable'
          'Restricted Access'
        when 'End of Year'
          'Return by End of Year'
        when 'End of Term'
          'Return by End of Term'
        else
          raw_policy
        end
      end

      # TODO: is this right? AlmaAvailability parses availability XML and gets a location_code
      def aeon_requestable?
        aeon_site_codes = PennLib::BlacklightAlma::CodeMappingsSingleton.instance.code_mappings.aeon_site_codes
        item_data['location']['value'].in? aeon_site_codes
      end

      def for_select(_options = {})
        {
          'id' => item_data['pid'],
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
          'in_place' => in_place?
        }
      end
    end
  end
end
