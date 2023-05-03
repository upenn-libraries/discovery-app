# frozen_string_literal: true

require 'rails_helper'
require 'penn_lib/marc'

# fake model spec to test the subject handling from lib/penn_lib/marc.rb
RSpec.describe PennLib::SubjectConfig, type: :model do
  subject(:subject_config) { PennLib::SubjectConfig }
  let(:rec) do
    MARC::XMLReader.new(
      File.join(Rails.root,'spec/fixtures/marcxml/9978004977403681.xml'),
      parser: :nokogiri
    ).first
  end

  describe '.prepare_subjects' do
    it 'does not include URIs from $1' do
      xfacet_data = subject_config.prepare_subjects(rec)[:xfacet]
      expect(xfacet_data).not_to include '{"val":"LGBTQ+ parents--https://homosaurus.org/v3/homoit0001075","prefix":"o"}'
      expect(xfacet_data).to include '{"val":"LGBTQ+ parents","prefix":"o"}'
    end
  end
end

RSpec.describe PennLib::Marc, type: :model do
  let(:marc) { PennLib::Marc.new(PennLib::CodeMappings.new(Rails.root.join('config/translation_maps'))) }
  let(:rec) do
    MARC::XMLReader.new(
      Rails.root.join('spec/fixtures/marcxml/9978004977403681.xml').to_s,
      parser: :nokogiri
    ).first
  end
  describe '.get_genre_display' do
    let(:genre_values) { marc.get_genre_display(rec, false).collect { |f| f[:value] } }
    it 'does not include un-approved ontology values' do
      expect(genre_values).not_to include 'Disallowed ontology term'
      expect(genre_values).to include 'Allowed subject ontology term'
      expect(genre_values).to include 'Allowed genre ontology term'
    end
    it 'does not include duplicate values' do
      expect(genre_values).to match_array genre_values.uniq
    end
    it 'does include values where subfield 2 is 0' do
      expect(genre_values).to include 'Displayed 655 _0'
    end
    it 'does include values where subfield 2 is 4' do
      expect(genre_values).to include 'Displayed 655 _4'
    end
    it 'does not include values where subfield 2 is 5' do
      expect(genre_values).not_to include 'Displayed 655 _5'
    end
  end
  describe '.get_author_display' do
    it 'does not include URI values from $1' do
      data = marc.get_author_display(rec)
      expect(data.first[:value]).not_to include '123456789'
    end
  end
  describe '.get_author_creator_values' do
    it 'does not include URIs from $1' do
      names = marc.get_author_creator_values(rec)
      expect(names.first).not_to include '123456789'
    end
  end
  describe '.get_author_creator_sort_values' do
    it 'does not include URIs from $1' do
      names = marc.get_author_creator_sort_values(rec)
      expect(names.first).not_to include '123456789'
    end
  end
  describe '.get_author_creator_1_search_values' do
    it 'does not include URIs from $1' do
      names = marc.get_author_creator_1_search_values(rec)
      expect(names.first).not_to include '123456789'
    end
  end
  describe '.get_author_creator_2_search_values' do
    it 'does not include URIs from $1' do
      names = marc.get_author_creator_2_search_values(rec)
      expect(names.first).not_to include '123456789'
    end
  end
  describe '.get_contained_within_values' do
    it 'does not include information from 773 subfields $7 or $w' do
      values = marc.get_contained_within_values(rec)
      expect(values).to eq ['University of Pennsylvania. School of Arts and Sciences. Computing Facilities and Services. Multimedia Educational Technology Services. Records, 1969-1991']
    end
  end
  context 'web link parsing for display' do
    context 'for a fund-based bookplate' do
      let(:weblink_rec) do
        MARC::XMLReader.new(
          Rails.root.join('spec/fixtures/marcxml/bookplated_record.xml').to_s,
          parser: :nokogiri
        ).first
      end
      let(:web_links) { marc.get_web_link_display(weblink_rec) }
      it 'has four web link entries' do
        expect(web_links.length).to eq 4
      end
      it 'has a bookplate img link entry with expected structure' do
        expect(web_links[1]).to eq({
          img_src: 'https://www.library.upenn.edu/sites/default/files/images/bookplates/SmidtFamilyModernContemporaryArt.gif',
          img_alt: 'The Smidt Family Modern and Contemporary Art Collection Fund Home Page Bookplate',
          linkurl: 'http://hdl.library.upenn.edu/1017.12/2554579'
        })
      end
      it 'has a bookplate img link entry with expected structure matching on "Endowment"' do
        expect(web_links[3]).to eq({
          img_src: 'https://www.library.upenn.edu/sites/default/files/images/bookplates/AppelbaumFamilyStudyCityRegionalPlanning.gif',
          img_alt: 'The Appelbaum Family Endowment for the Study of City and Regional Planning Home Page Bookplate',
          linkurl: 'http://hdl.library.upenn.edu/1017.12/2554348'
        })
      end
    end
  end
end
