# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StanfordIndexer, type: :model do
  include MarcXmlFixtures

  let(:indexer) { described_class.new }
  let(:record_1) do

  end

  it 'works' do
    expect(indexer.map_record(record_1)).to be_a Hash
  end
end
