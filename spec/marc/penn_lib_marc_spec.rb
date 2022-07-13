# frozen_string_literal: true

require 'rails_helper'
require 'penn_lib/marc'

# fake model spec to test the craziness that is lib/penn_lib/marc.rb
RSpec.describe PennLib::SubjectConfig, type: :model do
  let(:rec) do
    MARC::XMLReader.new(
      File.join(Rails.root,'spec/fixtures/marcxml/9978004977403681.xml'),
      parser: :nokogiri
    ).first
  end

  describe '.prepare_subjects' do
    it 'does not include URIs from $1' do
      xfacet_data = PennLib::SubjectConfig.prepare_subjects(rec)[:xfacet]
      expect(xfacet_data).not_to include '{"val":"LGBTQ+ parents--https://homosaurus.org/v3/homoit0001075","prefix":"o"}'
      expect(xfacet_data).to include '{"val":"LGBTQ+ parents","prefix":"o"}'
    end
  end
end
