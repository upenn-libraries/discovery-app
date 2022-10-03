# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolrDocument, type: :model do
  let(:solr_document) { SolrDocument.new(marcrecord_text: File.read(marc)) }

  let(:marc_with_multiple_264) { Rails.root.join('spec/fixtures/marcxml/with_multiple_264.xml') }
  let(:marc_with_260_and_264) { Rails.root.join('spec/fixtures/marcxml/with_260_and_264.xml') }
  let(:marc_with_264_4) { Rails.root.join('spec/fixtures/marcxml/with_264_4.xml') }

  [:chicago, :apa, :mla].each do |citation_format|
    describe "#export_as_#{citation_format}_citation_txt" do
      subject(:citation) { solr_document.send("export_as_#{citation_format}_citation_txt") }

      context 'when 260 and 264 publication fields present' do
        let(:marc) { marc_with_260_and_264 }

        it 'uses 264 field' do
          expect(citation).to include 'Chandigarh : Lokgeet Parkashan'
          expect(citation).to include '2010'
        end
      end

      context 'when multiple 264 publication fields present' do
        let(:marc) { marc_with_multiple_264 }

        it 'uses 264/1 field' do
          expect(citation).to include 'S. Fischer Verlag'
          expect(citation).to include '1912'
        end
      end

      context 'when 264/4 publication field present' do
        let(:marc) { marc_with_264_4 }

        it 'ignores 264/4 field' do
          expect(citation).to include 'Kerby'
          expect(citation).to include '1880'
        end
      end
    end
  end
end