
require 'penn_lib/marc'

# frozen_string_literal: true
class SolrDocument

  include Blacklight::Solr::Document
  include ExpandedDocs

      # The following shows how to setup this blacklight document to display marc documents
  extension_parameters[:marc_source_field] = :marcrecord_text
  extension_parameters[:marc_format_type] = :marcxml
  use_extension( Blacklight::Solr::Document::Marc) do |document|
    document.key?( :marcrecord_text  )
  end
  
  field_semantics.merge!(    
                         :last_updated => "recently_added_isort",
                         :title => "title",
                         :author => "author_creator_a",
                         :language => "language_a",
                         :format => "format_a"
                         )

  include Blacklight::Solr::Document::RisFields
  use_extension(Blacklight::Solr::Document::RisExport)

  ris_field_mappings.merge!(
    :TY => Proc.new {
      format = fetch('format_a', [])
      if format.member?('Book')
        'BOOK'
      elsif format.member?('Journal/Periodical')
        'JOUR'
      else
        'GEN'
      end
    },
    :TI => 'title',
    :AU => 'author_creator_a',
    :PY => Proc.new { pennlibmarc.get_ris_py_field(to_marc) },
    :CY => Proc.new { pennlibmarc.get_ris_cy_field(to_marc) },
    :PB => Proc.new { pennlibmarc.get_ris_pb_field(to_marc) },
    :ET => 'edition',
    :SN => Proc.new { pennlibmarc.get_ris_sn_field(to_marc) },
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
    # This needs to be called BEFORE any of the custom _display method definitions
    # in this class that override these definitions.
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
    @code_mappings ||= PennLib::CodeMappings.new(Rails.root.join('config').join('translation_maps'))
    @pennlibmarc ||= PennLib::Marc.new(@code_mappings)
  end

  def format_display
    @format_display ||= [ fetch('format_a') ] + pennlibmarc.get_format_display(to_marc)
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

  def local_notes_display
    if !is_crl?
      pennlibmarc.get_local_notes_display(to_marc)
    end
  end

  def offsite_display
    if is_crl?
      crl_id = fetch('id', '').gsub('CRL_', '')
      title = fetch('title', '')
      author = fetch('author_creator_a', []).first
      oclc_id = fetch('oclc_id', '')
      pennlibmarc.get_offsite_display(to_marc, crl_id, title, author, oclc_id)
    end
  end

  def web_link_display
    if !is_hathi?
      pennlibmarc.get_web_link_display(to_marc)
    end
  end

  # returns all the documents in this cluster, including this one
  def cluster_docs
    [ self ] + expanded_docs
  end

  def all_doc_ids_for_cluster
    cluster_docs.map { |doc| doc.id }
  end

  # returns the full text link field values for all the documents in the cluster
  def full_text_links_for_cluster_display
    structs = cluster_docs.map do |expanded_doc|
      field_value = expanded_doc.fetch('full_text_link_text_a', [])
      if field_value.present?
        {
          id: expanded_doc.id,
          value: field_value
        }
      end
    end.compact

    # sort so that order is always the same for any doc in cluster
    structs.sort { |x,y| x[:id] <=> y[:id] }.map { |item| item[:value] }.flatten
  end

  # used by blacklight_alma
  def alma_mms_id
    fetch('alma_mms_id', nil)
  end

  def alma_availability_mms_ids
    fetch('bound_with_ids_a', []) + [alma_mms_id]
  end

  def has_any_holdings?
    has?(:electronic_holdings_json) || has?(:physical_holdings_json)
  end

  def is_crl?
    fetch('id', '').start_with?('CRL')
  end

  def is_hathi?
    fetch('id', '').start_with?('HATHI')
  end

end
