# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MitIndexer, type: :model do
  include MarcXmlFixtures

  let(:index_data) { described_class.new.map_record marcxml_record_from marc_file }

  context 'record 1' do
    let(:marc_file) { 'pod_normalized/mit/record_1.xml' }

    it 'has the expected record_source_id of 14' do
      expect(index_data['record_source_id']).to eq [14]
    end

    it 'has the expected record_source of MIT' do
      expect(index_data['record_source_f']).to eq ['MIT']
    end
  end

end
