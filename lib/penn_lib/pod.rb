# frozen_string_literal: true

module PennLib
  module Pod

    POD_FILES_BASE_LOCATION = File.join Rails.root, 'pod_data'

    # @param [String] org
    # @param [String] stream
    # @return [TrueClass, FalseClass]
    def self.empty_or_existing_stream?(org, stream)
      org_folder = File.join POD_FILES_BASE_LOCATION, org
      # return true if no stream folders for this inst
      return true if Dir[org_folder].empty?

      Pathname.new(File.join(org_folder, stream)).directory?
    end

    # Represent file info about an available Normalized Marc XML file resource
    class RemoteNormalizedMarcFile

      attr_reader :resource, :location, :filename, :checksum, :date

      # @param [Object] resource
      # @param [String] org
      # @param [String] stream_id
      def initialize(resource, org, stream_id)
        @resource = resource
        @filename = resource.uri.to_s.split('/')[-1]
        @checksum = resource.metadata.hashes.dig 'md5'
        @date = resource.modified_time
        @org = org
        @stream_id = stream_id
        @location = File.join POD_FILES_BASE_LOCATION, org, stream_id
      end

      # @return [String]
      def saved_filename
        File.join @location, @filename
      end

      # @return [TrueClass, FalseClass]
      def download_and_save
        Net::HTTP.start(@resource.uri.host, @resource.uri.port, use_ssl: true) do |http|
          download = Net::HTTP::Get.new(@resource.uri)
          download['Authorization'] = "Bearer #{ENV['POD_ACCESS_TOKEN']}"
          http.request download do |response|
            File.open(saved_filename, 'wb') do |io|
              response.read_body do |chunk|
                io.write chunk
              end
            end
          end
        end
        @downloaded = true
      rescue StandardError => e
        puts "Failed to download #{@filename}: #{e.message}"
        @downloaded = false
      end

      # Compare to a file that's already present on the file system -
      # @return [TrueClass, FalseClass]
      def already_downloaded_ok?
        # you just downloaded this file...calling this is silly
        raise StandardError, 'You just downloaded this file...' if @downloaded

        # is on the filesystem already? with matching size and checksum?
        return false unless File.exist? saved_filename

        # compare checksums - this should catch a file of the same name
        # that overwrote a previous file in the aggregator (test)
        return false unless md5_checksum(saved_filename) == @checksum

        true
      end

      # @return [TrueClass, FalseClass]
      def downloaded?
        @downloaded
      end

      # @return [TrueClass, FalseClass]
      def valid_checksum?
        raise StandardError, 'File not yet downloaded' unless downloaded?

        md5_checksum(saved_filename) == @checksum
      end

      def md5_checksum(file)
        Digest::MD5.file(file).hexdigest
      end
    end

    # represent a POD Organization, and provide methods for working with
    # pulled data streams and indexing
    class Organization
      attr_reader :name, :home, :newest_stream, :indexer
      def initialize(name)
        @name = name
        @home = File.join POD_FILES_BASE_LOCATION, name
        @newest_stream = find_newest_stream
        @indexer = indexer_class
      end

      # @return [TrueClass, FalseClass]
      def should_index?
        newest_stream_gzfiles.any?
      end

      # @return [Array]
      def newest_stream_gzfiles
        # aggregator sometimes offers gzipped marcxml files as simply 'marcxml'
        Dir.glob %W[#{@newest_stream}*.xml.gz #{@newest_stream}marcxml]
      end

      def to_s
        @name
      end

      private

      def indexer_class
        "#{@name.titleize}Indexer".constantize
      end

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
