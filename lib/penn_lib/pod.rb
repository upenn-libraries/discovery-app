# frozen_string_literal: true

module PennLib
  module Pod

    POD_FILES_BASE_LOCATION = File.join Rails.root, 'pod_data'

    # represent a POD Organization, and provide methods for working with
    # pulled data streams and indexing
    class Organization
      attr_reader :name, :home, :newest_stream, :indexer
      def initialize(name)
        @name = name
        @home = File.join POD_FILES_BASE_LOCATION, name
        @newest_stream = find_newest_stream
        @indexer = "#{@name.titleize}Indexer".constantize
      end

      # @return [TrueClass, FalseClass]
      def should_index?
        newest_stream_gzfiles.any?
      end

      # @return [Array]
      def newest_stream_gzfiles
        Dir.glob "#{@newest_stream}*.xml.gz"
      end

      private

      # @return [String, nil]
      def find_newest_stream
        Dir.glob("#{@home}/*/").max_by do |dir|
          File.mtime dir
          dir
        end
      end
    end
  end
end
