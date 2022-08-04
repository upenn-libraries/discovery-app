# frozen_string_literal: true

require 'rails_helper'
require 'penn_lib/marc'

# fake model spec to test the subject handling from lib/penn_lib/marc.rb
RSpec.describe PennLib::SubjectConfig, type: :model do
  subject(:subject_config) { PennLib::SubjectConfig }
  let(:rec) do
    MARC::XMLReader.new(
      File.join(Rails.root,'spec/fixtures/marcxml/9978004977403681.xml'),
      parser: :nokogiri
    ).first
  end

  describe '.prepare_subjects' do
    it 'does not include URIs from $1' do
      xfacet_data = subject_config.prepare_subjects(rec)[:xfacet]
      expect(xfacet_data).not_to include '{"val":"LGBTQ+ parents--https://homosaurus.org/v3/homoit0001075","prefix":"o"}'
      expect(xfacet_data).to include '{"val":"LGBTQ+ parents","prefix":"o"}'
    end
  end
end

RSpec.describe PennLib::Marc, type: :model do
  let(:marc) { PennLib::Marc.new(PennLib::CodeMappings.new(Rails.root.join('config').join('translation_maps'))) }
  let(:rec) do
    MARC::XMLReader.new(
      File.join(Rails.root,'spec/fixtures/marcxml/9978004977403681.xml'),
      parser: :nokogiri
    ).first
  end
  describe '.get_author_display' do
    it 'does not include URI values from $1' do
      data = marc.get_author_display(rec)
      expect(data.first[:value]).not_to include '123456789'
    end
  end
  describe '.get_author_creator_values' do
    it 'does not include URIs from $1' do
      names = marc.get_author_creator_values(rec)
      expect(names.first).not_to include '123456789'
    end
  end
end
