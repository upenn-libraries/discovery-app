$:.unshift './config'

require 'date'

require 'traject'

require 'penn_lib/marc'

class MarcIndexer < Blacklight::Marc::Indexer
  # this mixin defines lambda facotry method get_format for legacy marc formats
  include Blacklight::Marc::Indexer::Formats
  include BlacklightSolrplugins::Indexer

  # This behaves like the wrapped MARC::Record object it contains
  # except that the #each method filters out fields with non-standard tags.
  class PlainMarcRecord

    def initialize(record)
      @record = record
      @valid_tag_regex ||= /^\d\d\d$/
    end

    def method_missing(*args)
      @record.send(*args)
    end

    def each
      for field in @record.fields
        yield field if field.tag =~ @valid_tag_regex
      end
    end
  end

  # Filter out enriched fields from ALMA because a lot of them can cause
  # the stored MARC XML in Solr to exceed max field size. Note that the
  # marc_view partial filters out non-standard MARC tags on display side too.
  # @return [Proc] proc object to be used by traject
  def get_plain_marc_xml
    lambda do |record, accumulator|
      accumulator << MARC::FastXMLWriter.encode(PlainMarcRecord.new(record))
    end
  end

  def initialize
    super

    settings do
      # type may be 'binary', 'xml', or 'json'
      provide "marc_source.type", "xml"
      # set this to be non-negative if threshold should be enforced
      provide 'solr_writer.max_skipped', -1

      # uncomment these lines to write to a file
      #store "writer_class_name", "Traject::JsonWriter"
      #store 'output_file', "traject_output.json"

      if defined? JRUBY_VERSION
        # 'store' overrides existing settings, 'provide' does not
        store 'reader_class_name', "Traject::Marc4JReader"
        store 'solr_writer.thread_pool', 4
        store 'processing_thread_pool', 4
      end

      store 'solr_writer.commit_on_close', false

    end

    pennlibmarc = PennLib::Marc.new(Rails.root.join('indexing'))

    to_field "id", trim(extract_marc("001"), :first => true) do |rec, acc, context|
      # TODO: prepend FRANKLIN_, HATHI_, etc. based on an environment variable?
      # or some other way to identify source of records
      acc.map! { |id| "FRANKLIN_#{id}" }

      # we do this check in the first 'id' field so that it happens early
      if pennlibmarc.is_boundwith_record(rec)
        context.skip!("Skipping boundwith record #{acc.first}")
      end
    end

    to_field "alma_mms_id", trim(extract_marc("001"), :first => true)

    to_field 'oclc_id' do |rec, acc|
      acc.concat(pennlibmarc.get_oclc_id_values(rec))
    end

    # do NOT use *_xml_stored_single because it uses a Str (max 32k) for storage
    to_field 'marcrecord_xml_stored_single_large', get_plain_marc_xml

    # Our keyword searches use pf/qf to search multiple fields, so
    # we don't need this field; leaving it commented out here just in case.
    #
    # to_field "text_search", extract_all_marc_values do |r, acc|
    #   acc.unshift(r['001'].try(:value))
    #   acc.replace [acc.join(' ')] # turn it into a single string
    # end

    to_field "access_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_access_values(rec))
    end

    to_field "format_f_stored", get_format

    author_creator_spec = %W{
      100abcdjq
      110abcdjq
      700abcdjq
      710abcdjq
      800abcdjq
      810abcdjq
      111abcen
      711abcen
      811abcen
    }.join(':')

    to_field "author_creator_f", extract_marc(author_creator_spec, :trim_punctuation => true)

    # TODO: logic here is exactly the same as author_creator_facet: cache somehow?
    to_field 'author_creator_xfacet', extract_marc(author_creator_spec, :trim_punctuation => true) do |r, acc|
      acc.map! { |v| references(v) }
    end

    to_field 'subject_f_stored' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_facet_values(rec))
    end

    to_field 'subject_search' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_search_values(rec))
    end

    to_field 'subject_xfacet' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_xfacet_values(rec))
    end

    to_field "language_f_stored", marc_languages("008[35-37]")

    to_field "language_search", marc_languages("008[35-37]")

    to_field "library_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_library_values(rec))
    end

    to_field "specific_location_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_specific_location_values(rec))
    end

    to_field "publication_date_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_publication_date_values(rec))
    end

    to_field "classification_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_classification_values(rec))
    end

    to_field "genre_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_genre_values(rec))
    end

    to_field "genre_search" do |rec, acc|
      acc.concat(pennlibmarc.get_genre_search_values(rec))
    end

    # Title fields

    to_field 'title_1_search' do |rec, acc|
      acc.concat(pennlibmarc.get_title_1_search_values(rec))
    end

    to_field 'title_2_search' do |rec, acc|
      acc.concat(pennlibmarc.get_title_2_search_values(rec))
    end

    to_field 'journal_title_1_search' do |rec, acc|
      acc.concat(pennlibmarc.get_journal_title_1_search_values(rec))
    end

    to_field 'journal_title_2_search' do |rec, acc|
      acc.concat(pennlibmarc.get_journal_title_2_search_values(rec))
    end

    to_field 'author_creator_1_search' do |rec, acc|
      acc.concat(pennlibmarc.get_author_creator_1_search_values(rec))
    end

    to_field 'author_creator_2_search' do |rec, acc|
      acc.concat(pennlibmarc.get_author_creator_2_search_values(rec))
    end

    to_field 'author_creator_a' do |rec, acc|
      acc.concat(pennlibmarc.get_author_creator_values(rec))
    end

    to_field 'author_880_a' do |rec, acc|
      acc.concat(pennlibmarc.get_author_880_values(rec))
    end

    to_field 'title' do |rec, acc|
      acc.concat(pennlibmarc.get_title_values(rec))
    end

    to_field 'title_880_a' do |rec,acc|
      acc.concat(pennlibmarc.get_title_880_values(rec))
    end

    to_field 'standardized_title_a' do |rec, acc|
      acc.concat(pennlibmarc.get_standardized_title_values(rec))
    end

    to_field 'title_xfacet' do |rec, acc|
      acc.concat(pennlibmarc.get_title_xfacet_values(rec))
      acc.map! { |v| references(v) }
    end

    to_field 'title_ssort' do |rec, acc|
      acc.concat(pennlibmarc.get_title_sort_values(rec))
    end

    # Author fields

    to_field 'author_creator_ssort' do |rec, acc|
      acc.concat(pennlibmarc.get_author_creator_sort_values(rec))
    end

    to_field 'edition' do |rec, acc|
      acc.concat(pennlibmarc.get_edition_values(rec))
    end

    to_field 'conference_a' do |rec, acc|
      acc.concat(pennlibmarc.get_conference_values(rec))
    end

    to_field 'series' do |rec, acc|
      acc.concat(pennlibmarc.get_series_values(rec))
    end

    to_field 'publication_a' do |rec, acc|
      acc.concat(pennlibmarc.get_publication_values(rec))
    end

    to_field 'contained_within_a'  do |rec, acc|
      acc.concat(pennlibmarc.get_contained_within_values(rec))
    end

    to_field 'publication_date_ssort' do |rec, acc|
      acc.concat(pennlibmarc.get_publication_date_sort_values(rec))
    end

    to_field 'recently_added_isort' do |rec, acc|
      acc.concat(pennlibmarc.get_recently_added_sort_values(rec))
    end

    to_field "isbn_isxn_stored",  extract_marc(%W{020az 022alz}, :separator=>nil) do |rec, acc|
      orig = acc.dup
      acc.map!{|x| StdNum::ISBN.allNormalizedValues(x)}
      acc << orig
      acc.flatten!
      acc.uniq!
    end

    to_field 'call_number_search' do |rec, acc|
      acc.concat(pennlibmarc.get_call_number_search_values(rec))
    end

    to_field 'physical_holdings_json' do |rec, acc|
      result = pennlibmarc.get_physical_holdings(rec)
      if result.present?
        acc << result.to_json
      end
    end

    to_field 'electronic_holdings_json' do |rec, acc|
      result = pennlibmarc.get_electronic_holdings(rec)
      if result.present?
        acc << result.to_json
      end
    end

    to_field 'conference_search' do |rec, acc|
      acc.concat(pennlibmarc.get_conference_search_values(rec))
    end

    to_field 'contents_note_search' do |rec, acc|
      acc.concat(pennlibmarc.get_contents_note_search_values(rec))
    end

    to_field 'corporate_author_search' do |rec, acc|
      acc.concat(pennlibmarc.get_corporate_author_search_values(rec))
    end

    to_field 'place_of_publication_search', extract_marc('260a:264|*1|a')

    to_field 'publisher_search', extract_marc('260b:264|*1|b')

    to_field 'pubnum_search', extract_marc('024a:028a')

    to_field 'series_search' do |rec, acc|
      acc.concat(pennlibmarc.get_series_search_values(rec))
    end

  end
end
