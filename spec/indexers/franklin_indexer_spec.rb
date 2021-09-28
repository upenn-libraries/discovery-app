# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FranklinIndexer, type: :model do
  include MarcXmlFixtures

  let(:index_data) { described_class.new.map_record marcxml_record_from marc_file }

  context 'record 1' do
    let(:marc_file) { 'penn/record1.xml' }

    it 'has the expected record_source_id of 1' do
      expect(index_data['record_source_id']).to eq [1]
    end
  end
end
