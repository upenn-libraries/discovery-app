# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolrDocument, type: :model do
  let(:solr_document) { SolrDocument.new(marcrecord_text: File.read(marc)) }

  let(:marc_with_multiple_264) { Rails.root.join('spec/fixtures/marcxml/with_multiple_264.xml') }
  let(:marc_with_260_and_264) { Rails.root.join('spec/fixtures/marcxml/with_260_and_264.xml') }
  let(:marc_with_264_4) { Rails.root.join('spec/fixtures/marcxml/with_264_4.xml') }

  describe '#export_as_apa_citation_txt' do
    subject(:apa_citation) { solr_document.export_as_apa_citation_txt }

    context 'when 260 and 264 publication fields present' do
      let(:marc) { marc_with_260_and_264 }

      it 'uses 264 field' do
        expect(apa_citation).to include 'Chandigarh : Lokgeet Parkashan'
      end
    end

    context 'when multiple 264 publication fields present' do
      let(:marc) { marc_with_multiple_264 }

      it 'uses 264/1 field' do
        expect(apa_citation).to include 'S. Fischer Verlag'
      end
    end

    context 'when 264/4 publication field present' do
      let(:marc) { marc_with_264_4 }

      it 'ignores 264/4 field' do
        expect(apa_citation).to include 'Kerby'
      end
    end
  end

  describe '#export_as_mla_citation_txt' do
    subject(:mla_citation) { solr_document.export_as_mla_citation_txt }

    context 'when 260 and 264 publication fields present' do
      let(:marc) { marc_with_260_and_264 }

      it 'uses 264 field' do
        expect(mla_citation).to include 'Chandigarh : Lokgeet Parkashan'
      end
    end

    context 'when multiple 264 publication fields present' do
      let(:marc) { marc_with_multiple_264 }

      it 'uses 264/1 field' do
        expect(mla_citation).to include 'S. Fischer Verlag'
      end
    end

    context 'when 264/4 publication field present' do
      let(:marc) { marc_with_264_4 }

      it 'ignores 264/4 field' do
        expect(mla_citation).to include 'Kerby'
      end
    end
  end

  describe '#export_as_chicago_citation_txt' do
    subject(:chicago_citation) { solr_document.export_as_chicago_citation_txt }

    context 'when 260 and 264 publication fields present' do
      let(:marc) { marc_with_260_and_264 }

      it 'uses 264 field' do
        expect(chicago_citation).to include 'Chandigarh : Lokgeet Parkashan'
      end
    end

    context 'when multiple 264 publication fields present' do
      let(:marc) { marc_with_multiple_264 }

      it 'uses 264/1 field' do
        expect(chicago_citation).to include 'S. Fischer Verlag'
      end
    end

    context 'when 264/4 publication field present' do
      let(:marc) { marc_with_264_4 }

      it 'ignores 264/4 field' do
        expect(chicago_citation).to include 'Kerby'
      end
    end
  end
end