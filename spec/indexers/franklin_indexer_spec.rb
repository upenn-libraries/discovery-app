# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FranklinIndexer, type: :model do
  include MarcXmlFixtures

  let(:indexer) { described_class.new }
  let(:record_1) { marcxml_record 'penn/record1.xml' }

  it 'works' do
    expect(indexer.map_record(record_1)).to be_a Hash
  end
end
