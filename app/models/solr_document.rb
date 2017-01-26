
require 'penn_lib/marc'

# frozen_string_literal: true
class SolrDocument 

  include Blacklight::Solr::Document    
      # The following shows how to setup this blacklight document to display marc documents
  extension_parameters[:marc_source_field] = :marc_xml
  extension_parameters[:marc_format_type] = :marcxml
  use_extension( Blacklight::Solr::Document::Marc) do |document|
    document.key?( :marc_xml  )
  end
  
  field_semantics.merge!(    
                         :title => "title_display",
                         :author => "author_display",
                         :language => "language_facet",
                         :format => "format"
                         )



  # self.unique_key = 'id'
  
  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension( Blacklight::Document::Email )
  
  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension( Blacklight::Document::Sms )

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Document::SemanticFields#field_semantics
  # and Blacklight::Document::SemanticFields#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension( Blacklight::Document::DublinCore)    

  def pennlibmarc
    @pennlibmarc ||= PennLib::Marc.new(Rails.root.join('indexing'))
  end

  def author_display
    @author_display ||= pennlibmarc.get_author_values_display(to_marc)
  end

  def standardized_title_display
    @standardized_title_display ||= pennlibmarc.get_standardized_title_values_display(to_marc)
  end

  def other_title_display
    @other_title_display ||= pennlibmarc.get_other_title_values_display(to_marc)
  end

  def edition_display
    @edition_display ||= pennlibmarc.get_edition_values_display(to_marc)
  end

  def publication_display
    @publication_display ||= begin
      values = pennlibmarc.get_publication_values_display(to_marc)
      if pennlibmarc.has_264_with_a_or_b(to_marc)
        values.concat(fetch('publication_a'))
      end
      values
    end
  end

  def distribution_display
    @distribution_display ||= pennlibmarc.get_distribution_values_display(to_marc)
  end

  def manufacture_display
    @manufacture_display ||= pennlibmarc.get_manufacture_values_display(to_marc)
  end

  def conference_display
    @conference_display ||= pennlibmarc.get_conference_values_display(to_marc)
  end

  def series_display
    @series_display ||= pennlibmarc.get_series_values_display(to_marc)
  end

  def format_display
    @format_display ||= [ fetch('format') ] + pennlibmarc.get_format_values_display(to_marc)
  end

  def cartographic_display
    @cartographic_display ||= pennlibmarc.get_cartographic_values_display(to_marc)
  end

  def fingerprint_display
    @fingerprint_display ||= pennlibmarc.get_fingerprint_values_display(to_marc)
  end

  def arrangement_display
    @arrangement_display ||= pennlibmarc.get_arrangement_values_display(to_marc)
  end

  def former_title_display
    @former_title_display ||= pennlibmarc.get_former_title_values_display(to_marc)
  end

  def continues_display
    @continues_display ||= pennlibmarc.get_continues_values_display(to_marc)
  end

  def continued_by_display
    @continued_by_display ||= pennlibmarc.get_continued_by_values_display(to_marc)
  end

  def genre_display
    @genre_display ||= begin
      should_link = format_display.any? { |v| v =~ /(Manuscript|Video)/ }
      pennlibmarc.get_genre_values_display(to_marc, should_link)
    end
  end

  def place_of_publication_display
    @place_of_publication_display ||= begin
      is_journal_or_periodical = format_display.any? { |v| v =~ /(Journal|Periodical)/ }
      if !is_journal_or_periodical
        pennlibmarc.get_place_of_publication_values_display(to_marc)
      else
        []
      end
    end
  end

  def language_display
    @language_display ||= pennlibmarc.get_language_values_display(to_marc)
  end

  def biography_display
    @biography_display ||= pennlibmarc.get_biography_values_display(to_marc)
  end

  def summary_display
    @summary_display ||= pennlibmarc.get_summary_values_display(to_marc)
  end

  def participant_display
    @participant_display ||= pennlibmarc.get_participant_values_display(to_marc)
  end

  def credits_display
    @credits_display ||= pennlibmarc.get_credits_values_display(to_marc)
  end

  def finding_aid_display
    @finding_aid_display ||= pennlibmarc.get_finding_aid_values_display(to_marc)
  end

  def related_collections_display
    @related_collections_display ||= pennlibmarc.get_related_collections_values_display(to_marc)
  end

  def cited_in_display
    @cited_in_display ||= pennlibmarc.get_cited_in_values_display(to_marc)
  end

  def publications_about_display
    @publications_about_display ||= pennlibmarc.get_publications_about_values_display(to_marc)
  end

  def cite_as_display
    @cite_as_display ||= pennlibmarc.get_cite_as_values_display(to_marc)
  end

  def contributor_display
    @contributor_display ||= pennlibmarc.get_contributor_values_display(to_marc)
  end

  def related_work_display
    @related_work_display ||= pennlibmarc.get_related_work_values_display(to_marc)
  end

  def contains_display
    @contains_display ||= pennlibmarc.get_contains_values_display(to_marc)
  end

  def other_edition_display
    @other_edition_display ||= pennlibmarc.get_other_edition_values_display(to_marc)
  end

  def contained_in_display
    @contained_in_display ||= pennlibmarc.get_contained_in_values_display(to_marc)
  end

  def constituent_unit_display
    @constituent_unit_display ||= pennlibmarc.get_constituent_unit_values_display(to_marc)
  end

end
