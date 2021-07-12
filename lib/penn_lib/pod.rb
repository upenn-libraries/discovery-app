# frozen_string_literal: true

module PennLib
  module Pod

    POD_FILES_BASE_LOCATION = File.join Rails.root, 'pod_data'

    # Represent file info about an available Normalized Marc XML file resource
    class NormalizedMarcFile

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

      # @return [TrueClass, FalseClass]
      def downloaded?
        @downloaded
      end

      # @return [TrueClass, FalseClass]
      def valid_checksum?
        raise StandardError, 'File not yet downloaded' unless downloaded?

        Digest::MD5.file(saved_filename).hexdigest == @checksum
      end
    end
  end
end
