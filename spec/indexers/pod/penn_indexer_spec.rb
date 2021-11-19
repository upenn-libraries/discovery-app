# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PennIndexer, type: :model do
  include MarcXmlFixtures

  let(:index_data) { described_class.new.map_record marcxml_record_from marc_file }

  context 'record 1' do
    let(:marc_file) { 'pod_normalized/penn/record_1.xml' }

    it 'has the expected record_source_id of 1' do
      expect(index_data['record_source_id']).to eq [1]
    end

    it 'has the expected record_source of Penn' do
      expect(index_data['record_source_f']).to eq ['Penn']
    end

    it 'has the expected access_f_stored value of Online' do
      expect(index_data['access_f_stored']).to eq ['Online']
    end
  end

end
