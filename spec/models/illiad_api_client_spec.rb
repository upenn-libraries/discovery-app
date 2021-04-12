require 'rails_helper'

RSpec.describe Illiad::ApiClient, type: :model do
  include MockIlliadApi
  let(:api) { described_class.new }
  context 'api book request submit' do
    let(:user) do
      OpenStruct.new data: { 'proxied_for' => 'testuser' }
    end
    context 'success' do
      let(:bib_data_book) do
        {
          'author' => 'Resnik, Michael D.',
          'booktitle' => 'Mathematics as a science of patterns /',
          'publisher' => 'Oxford University Press',
          'place' => 'Oxford : New York :',
          'year' => '1997.',
          'isbn' => '0198236085 (hb)',
          'edition' => ''
        }
      end
      # it 'returns a transaction number' do
      #   stub_transaction_post_success
      #   body = Illiad.book_request_body user.data['proxied_for'], bib_data_book, 'booksbymail'
      #   response = api.transaction body
      #   expect(response).to eq '123456'
      # end
    end
    context 'failure' do
      # it 'fails' do
      #   stub_transaction_post_failure
      #   body = 'invalid-body'
      #   expect do
      #     api.transaction body
      #   end.to raise_error IlliadApiClient::RequestFailed
      # end
    end
  end
  context 'user' do
    let(:user_info) do
      {
        'Username' => 'testuser',
        'LastName' => 'User',
        'FirstName' => 'Test',
        'EMailAddress' => 'testuser@upenn.edu',
        'NVTGC' => 'VPL'
      }
    end
    context 'lookup' do
      context 'success' do
        it 'returns user info' do
          stub_illiad_user_get_success
          response = api.get_user 'testuser'
          expect(response&.keys).to include :username, :emailaddress
        end
      end
      context 'failure' do
        it 'raises an exception' do
          stub_illiad_user_get_failure
          expect {
            api.get_user 'irrealuser'
          }.to raise_error Illiad::ApiClient::UserNotFound
        end
      end
    end
    context 'create' do
      context 'success' do
        it 'returns newly created user info' do
          stub_illiad_user_post_success
          response = api.create_user user_info
          expect(response&.dig(:username)).to eq 'testuser'
        end
      end
      context 'failure' do
        it 'raises an InvalidRequest exception if user data is invalid' do
          expect {
            api.create_user({})
          }.to raise_error Illiad::ApiClient::InvalidRequest
        end
        it 'raises an InvalidRequest exception if response code indicates invalidity' do
          stub_illiad_user_post_failure
          expect {
            api.create_user({ "Username": "test" })
          }.to raise_error Illiad::ApiClient::InvalidRequest
        end
      end
    end
  end
end
