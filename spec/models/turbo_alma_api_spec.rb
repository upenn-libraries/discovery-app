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
      stub_holdings_get_success
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
    context 'item request' do
      before do
        stub_item_request_post_success
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
        context 'with parseable response body' do
          before do
            allow(request).to receive(:item_pid).and_return('9876')
          end
          before do
            stub_item_request_post_failure
          end
          it 'raises an exception' do
            expect do
              described_class.submit_request request
            end.to raise_error TurboAlmaApi::Client::RequestFailed
          end
        end
        context 'with empty response body' do
          before do
            allow(request).to receive(:item_pid).and_return('0000')
          end
          before do
            stub_item_request_post_failure_empty
          end
          it 'raises an exception' do
            expect do
              described_class.submit_request request
            end.to raise_error TurboAlmaApi::Client::RequestFailed
          end
        end
      end
    end
    context 'title request (mms id only)' do
      before do
        stub_title_request_post_success
        allow(request).to receive(:mms_id).and_return('1234')
        allow(request).to receive(:user_id).and_return('testuser')
        allow(request).to receive(:holding_id).and_return(nil)
        allow(request).to receive(:item_pid).and_return(nil)
        allow(request).to receive(:pickup_location).and_return('VanPeltLib')
        allow(request).to receive(:comments).and_return('')
      end
      context 'success' do
        it 'returns a hash with the confirmation number' do
          response = described_class.submit_request request
          expect(response[:confirmation_number]).to eq 'ALMA26107399010003681'
        end
      end
      context 'failure' do
        context 'with parseable response body' do
          before do
            allow(request).to receive(:item_pid).and_return('9876')
          end
          before do
            stub_title_request_post_failure
          end
          it 'raises an exception' do
            expect do
              described_class.submit_request request
            end.to raise_error TurboAlmaApi::Client::RequestFailed
          end
        end
      end
    end
    context 'with Alma error response code handling' do
      context 'for code 401129 (no Item can fulfill request)' do
        before do
          stub_request_post_failure_no_item
          allow(request).to receive(:item_pid).and_return('1129')
        end
        it 'returns a hash with helpful error information' do
          response = described_class.submit_request request
          expect(response[:message]).to eq I18n.t('requests.messages.alma_response.no_item_for_request')
        end
      end
      context 'for code 401136 (request already exists)' do
        before do
          stub_request_post_failure_already_exists
          allow(request).to receive(:item_pid).and_return('1136')
        end
        it 'returns a hash with helpful error information' do
          response = described_class.submit_request request
          expect(response[:message]).to eq I18n.t('requests.messages.alma_response.request_already_exists')
        end
      end
    end
  end
end
