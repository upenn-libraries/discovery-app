# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvardIndexer, type: :model do
  include MarcXmlFixtures

  let(:indexer) { described_class.new }
  let(:record_1) { marcxml_record 'pod_normalized/harvard/record_1.xml' }
  let(:record_2) { marcxml_record 'pod_normalized/harvard/record_2.xml' }

  it 'works' do
    expect(indexer.map_record(record_1)).to be_a Hash
    expect(indexer.map_record(record_2)).to be_a Hash
  end
end
