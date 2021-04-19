# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TurboAlmaApi::Client, type: :model do
  include MockAlmaApi
  let(:item_identifiers) do
    { mms_id: '1234',
      holding_id: '2345',
      item_pid: '3456' }
  end

  context 'item retrieval' do
    before do
      stub_item_get_success
      stub_turbo_item_get_canary
      stub_turbo_item_get_full
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

  context '.request_options' do
    before do
      stub_bib_request_options
    end

    context 'by the bib' do
      it 'includes keys for electronic services' do
        options = described_class.request_options item_identifiers[:mms_id]
        expect(options.keys).to include 'PURCHASE', 'ILLIAD', 'RESOURCESHARING'
      end
    end
  end

  context '.submit_request' do
    let(:request) { instance_double TurboAlmaApi::Request }
    before do
      stub_request_post_success
      allow(request).to receive(:mms_id).and_return('1234')
      allow(request).to receive(:user_id).and_return('testuser')
      allow(request).to receive(:holding_id).and_return('2345')
      allow(request).to receive(:item_pid).and_return('3456')
      allow(request).to receive(:pickup_location).and_return('VanPeltLib')
      allow(request).to receive(:comments).and_return('')
    end
    context 'success' do
      before do
        allow(request).to receive(:item_pid).and_return('3456')
      end
      it 'returns a hash with the confirmation number' do
        response = described_class.submit_request request
        expect(response[:confirmation_number]).to eq 'ALMA26107399010003681'
      end
    end
    context 'failure' do
      before do
        allow(request).to receive(:item_pid).and_return('9876')
      end
      before do
        stub_request_post_failure
      end
      it 'returns a hash with an error message' do
        expect do
          described_class.submit_request request
        end.to raise_error TurboAlmaApi::Client::RequestFailed
      end
    end
  end
end
