# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvardIndexer, type: :model do
  include MarcXmlFixtures

  let(:index_data) { described_class.new.map_record marcxml_record_from marc_file }

  context 'record 1' do
    let(:marc_file) { 'pod_normalized/harvard/record_1.xml' }

    it 'has the expected record_source_id of 8' do
      expect(index_data['record_source_id']).to eq [8]
    end

    it 'has the expected record_source of Harvard' do
      expect(index_data['record_source_f']).to eq ['Harvard']
    end
  end

  context 'record 2' do
    let(:marc_file) { 'pod_normalized/harvard/record_2.xml' }

  end
end
