# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JhuIndexer, type: :model do
  include MarcXmlFixtures

  let(:index_data) { described_class.new.map_record marcxml_record_from marc_file }

  context 'record 1' do
    let(:marc_file) { 'pod_normalized/jhu/record_1.xml' }

    it 'has the expected record_source_id of 13' do
      expect(index_data['record_source_id']).to eq [13]
    end

    it 'has the expected record_source of Johns Hopkins' do
      expect(index_data['record_source_f']).to eq ['Johns Hopkins']
    end
  end
end
