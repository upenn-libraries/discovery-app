
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

  class << self
    # Dynamically define methods corresponding to get_*_display methods in PennLib::Marc.
    # This needs to be called BEFORE any of the custom _display methods in this class
    # that shouldn't be delegated in this way.
    def define_display_methods
      PennLib::Marc.instance_methods
          .select { |m| m.to_s.end_with?('_display') }
          .map { |m| m.to_s.start_with?('get_') ? m.to_s[4..-1].to_sym : m }
          .each do |method_name|
        define_method method_name do
          # cache the result in an instance var of the same name
          if instance_variable_defined?("@#{method_name}")
            result = instance_variable_get("@#{method_name}")
          else
            result = pennlibmarc.send("get_#{method_name}", to_marc)
            instance_variable_set("@#{method_name}", result)
          end
          return result
        end
      end
    end
  end

  define_display_methods

  def pennlibmarc
    @pennlibmarc ||= PennLib::Marc.new(Rails.root.join('indexing'))
  end

  def publication_display
    @publication_display ||= begin
      values = pennlibmarc.get_publication_display(to_marc)
      if pennlibmarc.has_264_with_a_or_b(to_marc)
        values.concat(fetch('publication_a'))
      end
      values
    end
  end

  def format_display
    @format_display ||= [ fetch('format') ] + pennlibmarc.get_format_display(to_marc)
  end

  def genre_display
    @genre_display ||= begin
      should_link = format_display.any? { |v| v =~ /(Manuscript|Video)/ }
      pennlibmarc.get_genre_display(to_marc, should_link)
    end
  end

  def place_of_publication_display
    @place_of_publication_display ||= begin
      is_journal_or_periodical = format_display.any? { |v| v =~ /(Journal|Periodical)/ }
      if !is_journal_or_periodical
        pennlibmarc.get_place_of_publication_display(to_marc)
      else
        []
      end
    end
  end

end
