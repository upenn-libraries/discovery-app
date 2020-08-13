# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FranklinAlmaController, type: :request do
  def mock_availability_response(response)
    allow_any_instance_of(PennLib::BlacklightAlma::AvailabilityApi).to(
      receive(:get_availability).and_return(response)
    )
  end
  context 'availability' do
    context 'for print materials' do
      # Contingency, irony, and solidarity / Richard Rorty
      let(:test_print_response) do
        { 'availability' =>
              { '999763063503681' =>
                    { 'requests' => nil, 'holdings' => [
                      { 'mmsid' => '999763063503681', 'holding_id' => '22355842850003681', 'institution' => '01UPENN_INST',
                        'library_code' => 'AnnenLib', 'location' => 'Annenberg Library - Reserve',
                        'call_number' => 'P106 .R586 1989', 'availability' => 'available', 'total_items' => '1',
                        'non_available_items' => '0', 'location_code' => 'annbrese', 'call_number_type' => '0',
                        'priority' => '1', 'library' => 'Annenberg Library', 'inventory_type' => 'physical',
                        'link_to_aeon' => false },
                      { 'mmsid' => '999763063503681', 'holding_id' => '22355842870003681', 'institution' => '01UPENN_INST',
                        'library_code' => 'VanPeltLib', 'location' => 'Van Pelt Library', 'call_number' => 'P106 .R586 1989',
                        'availability' => 'available', 'total_items' => '1', 'non_available_items' => '0',
                        'location_code' => 'vanp', 'call_number_type' => '0', 'priority' => '2', 'library' => 'Van Pelt Library',
                        'inventory_type' => 'physical', 'link_to_aeon' => false }
                    ] } } }
      end
      before { mock_availability_response test_print_response }
      it 'returns valid JSON' do
        get '/alma/availability', id_list: '999763063503681', format: :json
        expect(response.status).to eq 200
        expect(JSON.parse(response.body)).to be_a Hash
      end
    end
    context 'for electronic materials' do
      # The jungle / Upton Sinclair
      let(:test_electronic_response) do
        { 'availability' =>
              { '9977445699903681' =>
                    { 'requests' => nil, 'holdings' => [
                      { 'portfolio_pid' => '53572532130003681', 'collection_id' => '61499910360003681',
                        'activation_status' => 'Available', 'collection' => 'Ebook Central College Complete',
                        'interface_name' => 'Ebook Central', 'link_to_service_page' =>
                            'publishing_base_url undefined?u.ignore_date_coverage=true&rft.mms_id=9977445699903681',
                        'inventory_type' => 'electronic' },
                      { 'portfolio_pid' => '53570734140003681', 'collection_id' => '61496732090003681',
                        'activation_status' => 'Available', 'collection' => 'Ebook Central Academic Complete',
                        'interface_name' => 'Ebook Central', 'link_to_service_page' =>
                            'publishing_base_url undefined?u.ignore_date_coverage=true&rft.mms_id=9977445699903681',
                        'inventory_type' => 'electronic' }
                    ] } } }
      end
      before { mock_availability_response test_electronic_response }
      it 'returns valid JSON' do
        get '/alma/availability', id_list: '9977445699903681', format: :json
        expect(response.status).to eq 200
        expect(JSON.parse(response.body)).to be_a Hash
      end
    end
    context 'error cases' do
      before { mock_availability_response nil }
      it 'returns an error if no parameter provided' do
        get '/alma/availability', format: :json
        expect(JSON.parse(response.body)['error']).to eq 'No id_list parameter'
      end
    end

  end
  context 'single_availability' do
    # TODO: there are so many remote requests here it will be difficult to
    # mock them. VCR could be used...
    it 'returns a Hash of data/metadata' do
      request_context = JSON.generate({ pickupable: nil, hathi_etas: false, hathi_pd: false,
                                      monograph: true })
      get '/alma/single_availability', mms_id: '9977445699903681',
                                       request_context: request_context,
                                       format: :json
      expect(response.status).to eq 200
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to be_a Hash
      expect(parsed_response.keys).to include 'metadata', 'data'
      expect(parsed_response['metadata']).to be_a Hash
      expect(parsed_response['data']).to be_an Array
    end
  end
  context 'holding_details' do
    it 'is broken but still return 200' do
      get '/alma/holding_details',
          mms_id: '999763063503681',
          holding_id: '22355842850003681',
          format: :json
      expect(response.status).to eq 200
    end
  end
  context 'request_options' do
    it 'does something' do
      request_context = JSON.generate({ pickupable: false, hathi_etas: false, hathi_pd: false,
                                        monograph: true })
      get '/alma/request_options',
          mms_id: '9977445699903681',
          request_context: request_context,
          format: :json
      parsed_response = JSON.parse(response.body)
      expect(response.status).to eq 200
      expect(parsed_response).to be_an Array
      expect(parsed_response.length).to eq 0
    end
  end
end
