module PennLib
  # methods to facilitate retrieval of subject specialist data from PennLib Drupal
  module SubjectSpecialists
    # return hash of subjects for use in display of subject specialist info
    def subjects
      specialists = ActiveSupport::HashWithIndifferentAccess.new
      subjects = ActiveSupport::HashWithIndifferentAccess.new
      specialists_url = 'https://www.library.upenn.edu/rest/views/subject-specialists?_format=json'
      live_specialists_data = JSON.parse(Faraday.get(specialists_url).body)
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
          specialty[:portrait] = "https://www.library.upenn.edu#{specialty['thumbnail']}"
          specialists[name] = specialty
        end
      end
      subjects.each do |subject, staff|
        subjects[subject] = staff.map { |name| specialists[name] }
      end
    end
  end
end
