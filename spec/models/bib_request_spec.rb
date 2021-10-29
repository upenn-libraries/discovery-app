# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BibRequest, type: :model do
  include MockAlmaApi

  before { stub_bib_get }

  let(:bib_request) { described_class.new '12345' }

  it 'responds to expected form fields properly' do
    expect(bib_request.title).to eq 'American treasure and the price revolution in Spain, 1501-1650 /'
    expect(bib_request.author).to eq 'Hamilton, Earl J.'
    expect(bib_request.publisher).to eq 'Harvard university press,'
    expect(bib_request.pub_place).to eq 'Cambridge, Mass.,'
    expect(bib_request.pub_date).to eq '1934.'
    expect(bib_request.isxn).to be_nil
    expect(bib_request.other_identifiers).to be_an Array
  end
end
