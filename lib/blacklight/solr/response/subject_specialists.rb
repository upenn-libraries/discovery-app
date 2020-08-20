# require "active_support/core_ext/hash/indifferent_access"

module Blacklight::Solr::Response::SubjectSpecialists
  class Constants
    SPECIALISTS = JSON.parse(File.read(Rails.root.join('config', 'translation_maps', 'expert_help_directory.json'))).with_indifferent_access
    SUBJECTS = JSON.parse(File.read(Rails.root.join('config', 'translation_maps', 'expert_help_subjects.json'))).with_indifferent_access
  end
end
