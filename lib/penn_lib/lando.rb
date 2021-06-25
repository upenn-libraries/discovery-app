# frozen_string_literal: true

module PennLib
  # helper methods for interacting with Lando for development
  module Lando
    SOLR_CONTAINER_NAME = 'gibneysolr'.freeze
    SOLR_CONTAINER_USER = 'solr'.freeze
    class << self
      # Run a command in a Lando container
      # @param [String] command
      # @param [Hash] options
      def run(command, options = {})
        cmd = "lando ssh #{options[:container]}"
        cmd += " -u #{options[:user]}" if options[:user]
        cmd += " '-c #{command}'"
        system cmd
      end

      # Run a command in the Solr container as solr user
      # @param [String] command
      def solr_run(command)
        run command, solr_run_opts
      end

      # Start GibneySolr
      # @return [TrueClass, FalseClass, nil]
      def start_solr
        solr_run '/opt/solr/bin/solr start -c -m 2g -p 8983 -Dsolr.jetty.request.header.size=65536'
      end

      # Create a Solr collection
      # @param [String] name
      # @param [String] config
      # @return [TrueClass, FalseClass, nil]
      def create_collection(name, config)
        solr_run "/opt/solr/bin/solr create_collection -c #{name} -d #{config}"
      end

      # Delete an existing collection
      # @param [String] name
      # @return [TrueClass, FalseClass, nil]
      def delete_collection(name)
        solr_run "/opt/solr/bin/solr delete -c #{name}"
      end

      # Copy Solr config from Lando mount to Solr configset dir
      # @param [String] name
      # @return [TrueClass, FalseClass, nil]
      def copy_config(name)
        solr_run "cp -r /app/tmp/solr_conf/#{name} /opt/solr/server/solr/configsets/#{name}"
      end

      def load_json_data(json_file)
        status = Open3.capture2e "curl -sX POST 'http://franklin.solr.lndo.site:8983/solr/franklin-dev/update/json?commit=true' --data-binary @#{json_file} -H 'Content-type:application/json'"
        puts status.join
      end

      # Check if collections exist in solr container
      # @return [TrueClass, FalseClass]
      def collections_exist?
        status = Open3.capture2e("lando ssh #{SOLR_CONTAINER_NAME} -u #{SOLR_CONTAINER_USER} -c '/opt/solr/bin/solr status'")
        status.join.include? '"collections":"2"'
      end

      private

      # @return [Hash{Symbol->String}]
      def solr_run_opts
        { container: SOLR_CONTAINER_NAME, user: SOLR_CONTAINER_USER }
      end
    end
  end
end
