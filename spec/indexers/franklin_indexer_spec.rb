# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FranklinIndexer, type: :model do
  include MarcXmlFixtures
  let(:indexer) { described_class.new }
  let(:record_1_filename) { marcxml_file 'penn/record1.xml' }
  let(:record_1_object) { MARC::XMLReader.new(record_1_filename).first }
  it 'works' do
    expect(indexer.map_record(record_1_object)).to be_a Hash
  end
end
