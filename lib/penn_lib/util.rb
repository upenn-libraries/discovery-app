
require 'zlib'

module PennLib

  module Util

    class << self

      # returns a file IO object, using a GzipReader wrapper if filename ends in .gz
      def openfile(path)
        if path.end_with?('.gz')
          Zlib::GzipReader.new(File.open(path), :external_encoding => 'UTF-8')
        else
          File.open(path)
        end
      end

      # Empties and re-populates the passed-in document_actions with keys ordered in the
      # action_list argument. This exists because Blacklight doesn't let you order/reorder
      # document actions in Blacklight::Configuration.
      #
      # For safety, this will raise an exception if you pass in action names in action_list
      # that don't exist. Action names that are not in the explicit list are appended in the
      # order in which they originally appeared.
      #
      # @param [NestedOpenStructWithHashAccess] document_actions
      # @param [Array] action_list array of symbols
      def reorder_document_actions(document_actions, *action_list)
        orig = document_actions.dup

        orig.keys.each { |key| document_actions.delete_field(key) }

        unknown_actions = action_list.select { |action_name| !orig.keys.include?(action_name) }
        if unknown_actions.any?
          raise "Unknown actions passed to #reorder_document_actions: #{unknown_actions}, the following actions exist: #{orig.keys}"
        end

        all_keys = action_list + (orig.keys - action_list)
        all_keys.each do |action_name|
          document_actions[action_name] = orig[action_name]
        end
      end

    end

  end
end