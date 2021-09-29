require 'rails_helper'

RSpec.describe AlmaOptionOrdering do
  let(:ordering) { Class.new { extend AlmaOptionOrdering  } }

  describe '#compare_services' do
    it 'return negative when comparing "Publisher Website" and "Vogue Magazine Archive"' do
      expect(ordering.compare_services(
        { 'collection' => 'Vogue Magazine Archive' },
        { 'collection' => 'Publisher Website' }
      )).to be_negative
    end

    it 'return positive when comparing "Publisher Website" and "Vogue Magazine Archive"' do
      expect(ordering.compare_services(
        { 'collection' => 'Publisher Website' },
        { 'collection' => 'Vogue Magazine Archive' }
      )).to be_positive
    end

    it 'return negative when comparing "Vogue Magazine Archive" (a collection) and "Nature" (an interface)' do
      expect(ordering.compare_services(
        { 'collection' => 'Publisher Website' },
        { 'interface' => 'Nature' }
      )).to be_positive
    end
  end

  describe '#compate_holdings' do
    it 'returns negative when comparing "Van Pelt Library" and "Libra"' do
      expect(ordering.compare_holdings(
        { 'library_code' => 'Van Pelt Library' },
        { 'library_code' => 'Libra' }
      )).to be_negative
    end

    it 'returns negative when comparing "Libra" and "Van Pelt Library"' do
      expect(ordering.compare_holdings(
        { 'library_code' => 'Van Pelt Library' },
        { 'library_code' => 'Libra' }
      )).to be_negative
    end
  end

  context 'when #compare_services is used with Hash#sort!' do
    it 'sorts collections expected' do
      holdings = [
        { 'collection' => 'Vogue Magazine Archive' },
        { 'collection' => 'Publisher Website' }
      ]
      expect(
        holdings.sort! { |a, b| ordering.compare_services(a, b) }
        ).to eq(
               [{ 'collection' => 'Publisher Website' },
                { 'collection' => 'Vogue Magazine Archive' }]
             )
    end

    it 'sorts collections and interfaces expected' do
      holdings = [
        { 'interface' => 'Nature' },
        { 'collection' => 'Publisher Website' },
        { 'collection' => 'Factiva' },
        { 'collection' => 'Academic OneFile' }
      ]
      expect(
        holdings.sort! { |a, b| ordering.compare_services(a, b) }
        ).to eq(
               [{ 'collection' => 'Publisher Website' },
                { 'collection' => 'Academic OneFile' },
                { 'interface' => 'Nature' },
                { 'collection' => 'Factiva' }]
             )
    end
  end
end
