# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TurboAlmaApi::Client, type: :model do
  include MockAlmaApi

  before do
    stub_item_get_success
    stub_turbo_item_get_canary
    stub_turbo_item_get_full
  end

  let(:item_identifiers) do
    { mms_id: '1234',
      holding_id: '2345',
      item_pid: '3456' }
  end

  context '.item_for' do
    it 'returns a PennItem' do
      expect(described_class.item_for(item_identifiers))
        .to be_an TurboAlmaApi::Bib::PennItem
    end
  end

  context '.all_items_for' do
    it 'pulls and aggregates PennItems for the given MMS ID' do
      items = described_class.all_items_for item_identifiers[:mms_id]
      expect(items.length).to eq 2
      expect(items.first).to be_a TurboAlmaApi::Bib::PennItem
    end
  end
end
