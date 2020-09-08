module PennLib
  # methods to facilitate retrieval of subject specialist data from PennLib
  # Drupal site
  module SubjectSpecialists
    DRUPAL_SPECIALISTS_URL =
      'https://www.library.upenn.edu/rest/views/subject-specialists?_format=json'.freeze
    CACHE_KEY = :subject_specialist_data

    class << self
      # Returns specialist info hash, and sets the cached value if needed,
      # returning nil if neither the cached date nor the live data passes
      # the seems_legit? test
      # @return [Hash, nil]
      def data
        cached_data = Rails.cache.read CACHE_KEY
        return cached_data if seems_legit? cached_data

        cache_data
      end

      # Set specialist data in cache if it passes the seems_legit? test
      # If it fails, return nil. THe display helper should then render the view
      # that doesn't require the specialist info
      # @return [Hash, nil]
      def cache_data
        data = subjects
        return nil unless seems_legit? data

        Rails.cache.write CACHE_KEY, data, expires_in: 24.hours
        data
      end

      # Roughly determine if data is a valid subject_specialists data
      # structure. This ain't pretty but it is what it is.
      # @param [Hash] data
      # @return [TrueClass, FalseClass]
      def seems_legit?(data)
        # ensure we aren't dealing with a blank value
        return false if data.blank?

        # ensure first array element is also an array
        return false unless data.first.is_a? Array

        # ensure the second element of the first array element is also an
        # array
        return false unless data.first.second&.is_a? Array

        # ensure the place where we expect the actual hash of data has one of
        # the keys we expect
        return false unless data.first.second.first&.key? 'subject_specialty'

        true
      end

      # return hash of subjects for use in display of subject specialist info
      # @return [Hash]
      def subjects
        specialists = ActiveSupport::HashWithIndifferentAccess.new
        subjects = ActiveSupport::HashWithIndifferentAccess.new
        live_specialists_data = retrieve_specialist_json
        return unless live_specialists_data

        live_specialists_data.each do |specialty|
          # nasty way to make the subject hash key match Drupal anchor tag ids
          subject_key = specialty['subject_specialty'].gsub(/[&#;]/, '')
                                                      .parameterize.underscore
          specialty = specialty.transform_values { |v| CGI.unescapeHTML v }
          name = specialty['full_name'].parameterize.underscore
          subjects[subject_key] = [] unless subjects[subject_key]
          subjects[subject_key] << name
          if specialists[name]
            specialists[name][:subjects] << specialty['subject_specialty']
          else
            specialty[:subjects] = [specialty['subject_specialty']]
            specialty[:display_name] = specialty['full_name']
            specialty[:portrait] =
              "https://www.library.upenn.edu#{specialty['thumbnail']}"
            specialists[name] = specialty
          end
        end
        subjects.each do |subject, staff|
          subjects[subject] = staff.map { |name| specialists[name] }
        end
      end

      # Pull and parse data from Drupal endpoint
      # Will retry up to 2 times and return nil if there are issues parsing JSON
      # @return [Hash, NilClass]
      def retrieve_specialist_json
        connection = Faraday.new do |conn|
          conn.request :retry, max: 2, interval: 0.1, backoff_factor: 2
          conn.adapter :net_http
        end
        response_body = connection.get(DRUPAL_SPECIALISTS_URL).body
        JSON.parse(response_body)
      # handle attempt to parse nil or empty response, as well as connection
      # errors
      rescue TypeError, JSON::JSONError, Faraday::ClientError => _e
        nil
      end
    end
  end
end
