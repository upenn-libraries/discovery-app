require 'rails_helper'

RSpec.describe AlmaOptionOrdering do
  let(:ordering) { Class.new { extend AlmaOptionOrdering  } }

  describe '#compare_services' do
    it 'return negative when comparing "Publisher website" and "Vogue Magazine Archive"' do
      expect(ordering.compare_services(
        { 'collection' => 'Vogue Magazine Archive' },
        { 'collection' => 'Publisher website' }
      )).to be_negative
    end

    it 'return positive when comparing "Publisher website" and "Vogue Magazine Archive"' do
      expect(ordering.compare_services(
        { 'collection' => 'Publisher website' },
        { 'collection' => 'Vogue Magazine Archive' }
      )).to be_positive
    end

    it 'return negative when comparing "Vogue Magazine Archive" (a collection) and "Nature" (an interface)' do
      expect(ordering.compare_services(
        { 'collection' => 'Publisher website' },
        { 'interface' => 'Nature' }
      )).to be_negative
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

  context 'when #compare_services is used with Hash#sort' do
    it 'sorts collections as expected' do
      holdings = [
        { 'collection' => 'Vogue Magazine Archive' },
        { 'collection' => 'Publisher website' }
      ]
      sorted = holdings.sort { |a, b| ordering.compare_services(a, b) }
      expect(sorted).to eq(
        [{ 'collection' => 'Publisher website' },
         { 'collection' => 'Vogue Magazine Archive' }]
      )
    end

    it 'sorts collections and interfaces as expected' do
      holdings = [
        { 'interface' => 'Nature' },
        { 'collection' => 'Publisher website' },
        { 'collection' => 'Mike\'s Memoir Archive' },
        { 'collection' => 'Factiva' },
        { 'collection' => 'Academic OneFile' }
      ]
      sorted = holdings.sort { |a, b| ordering.compare_services(a, b) }
      expect(sorted).to eq(
        [{ 'collection' => 'Publisher website' },
         { 'collection' => 'Academic OneFile' },
         { 'collection' => 'Mike\'s Memoir Archive' },
         { 'interface' => 'Nature' },
         { 'collection' => 'Factiva' }]
      )
    end
  end
end
