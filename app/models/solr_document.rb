
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

end
