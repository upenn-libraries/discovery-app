$:.unshift './config'

require 'date'

# This fixes a bug in older versions of glibc, where name resolution under high load sometimes fails.
# We require this here, because indexing jobs don't load Rails initializers
require 'resolv-replace'

require 'traject'

require 'penn_lib/marc'
require 'penn_lib/code_mappings'

# Indexer for Franklin-native records (i.e. from Alma).
# This is also used as a parent class for Hathi and CRL
# since the vast majority of the indexing rules are the same.
# Overrideable field definitions should go into define_* methods
# and called in this constructor.
class FranklinIndexer < BaseIndexer

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

    # append extra params to the Solr update URL for solr-side cross reference handling
    # and duplicate ID deletion
    processors = [ 'xref-copyfield', 'fl-multiplex', 'shingles' ]
    if ENV['SOLR_USE_UID_DISTRIB_PROCESSOR']
      # disable; handle deletion outside of solr, either permanently or pending bug fixes
      #processors << 'uid-distrib'
    end

    solr_update_url = [ ENV['SOLR_URL'].chomp('/'), 'update', 'json' ].join('/') + "?processor=#{processors.join(',')}"

    settings do
      # type may be 'binary', 'xml', or 'json'
      provide "marc_source.type", "xml"
      # set this to be non-negative if threshold should be enforced
      provide 'solr_writer.max_skipped', -1

      provide 'solr.update_url', solr_update_url

      store 'writer_class_name', 'PennLib::FranklinSolrJsonWriter'

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
      store 'solr_writer.batch_size', 2000

    end

    define_all_fields
  end

  def define_all_fields

    define_id

    define_grouped_id

    define_record_source_id

    define_record_source_facet

    define_mms_id

    define_oclc_id

    define_cluster_id

    define_full_text_link_text_a

    # do NOT use *_xml_stored_single because it uses a Str (max 32k) for storage
    to_field 'marcrecord_xml_stored_single_large', get_plain_marc_xml

    # Our keyword searches use pf/qf to search multiple fields, so
    # we don't need this field; leaving it commented out here just in case.
    #
    # to_field "text_search", extract_all_marc_values do |r, acc|
    #   acc.unshift(r['001'].try(:value))
    #   acc.replace [acc.join(' ')] # turn it into a single string
    # end

    define_access_facet

    to_field 'format_f_stored' do |rec, acc|
      acc.concat(pennlibmarc.get_format(rec))
    end

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

    # this is now automatically copied on the Solr side
    # to_field "author_creator_f", extract_marc(author_creator_spec, :trim_punctuation => true)

    # TODO: logic here is exactly the same as author_creator_facet: cache somehow?
    to_field 'author_creator_xfacet2_input', extract_marc(author_creator_spec, :trim_punctuation => true) do |r, acc|
      acc.map! { |v| 'n' + v }
    end

    # this is now automatically copied on the Solr side
    # to_field 'subject_f_stored' do |rec, acc|
    #   acc.concat(pennlibmarc.get_subject_facet_values(rec))
    # end

    to_field "db_type_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_db_types(rec))
    end

    to_field "db_category_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_db_categories(rec))
    end

    to_field "db_subcategory_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_db_subcategories(rec))
    end

    to_field 'subject_search' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_search_values(rec))
    end

    to_field 'subject_xfacet2_input' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_xfacet_values(rec))
    end

    to_field 'toplevel_subject_f' do |rec, acc|
      acc.concat(pennlibmarc.get_subject_facet_values(rec, true))
    end

    to_field 'call_number_xfacet' do |rec, acc|
      acc.concat(pennlibmarc.get_call_number_xfacet_values(rec))
    end

    to_field "language_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_language_values(rec))
    end

    to_field "language_search" do |rec, acc|
      acc.concat(pennlibmarc.get_language_values(rec))
    end

    to_field "library_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_library_values(rec))
    end

    to_field "specific_location_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_specific_location_values(rec))
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
    end

    to_field 'title_nssort' do |rec, acc|
      acc.concat(pennlibmarc.get_title_sort_values(rec))
    end

    to_field 'title_sort_tl' do |rec, acc|
      acc.concat(pennlibmarc.get_title_sort_filing_parts(rec, false))
      pennlibmarc.append_title_variants(rec, acc)
    end

    # Author fields

    to_field 'author_creator_nssort' do |rec, acc|
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

    to_field 'elvl_rank_isort' do |rec, acc|
      val = pennlibmarc.get_encoding_level_rank(rec)
      acc << val if val
    end

    to_field 'hld_count_isort' do |rec, acc|
      val = pennlibmarc.get_hld_count(rec)
      acc << val if val
    end

    to_field 'prt_count_isort' do |rec, acc|
      val = pennlibmarc.get_prt_count(rec)
      acc << val if val
    end

    each_record do |rec, ctx|
      ctx.clipboard.tap do |c|
        c[:timestamps] = pennlibmarc.prepare_timestamps(rec)
        c[:dates] = pennlibmarc.prepare_dates(rec)
      end
    end

    to_field 'recently_added_isort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:timestamps, :most_recent_add)
      acc << val if val
    end

    to_field 'last_update_isort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:timestamps, :last_update)
      acc << val if val
    end

    to_field 'publication_date_ssort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :pub_date_sort)
      acc << val if val
    end

    to_field 'pub_min_dtsort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :pub_date_minsort)
      acc << val if val
    end

    to_field 'pub_max_dtsort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :pub_date_maxsort)
      acc << val if val
    end

    to_field 'content_min_dtsort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :content_date_minsort)
      acc << val if val
    end

    to_field 'content_max_dtsort' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :content_date_maxsort)
      acc << val if val
    end

    to_field 'publication_date_f_stored' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :pub_date_decade)
      acc << val if val
    end

    to_field 'publication_dr' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :pub_date_range)
      acc << val if val
    end

    to_field 'content_dr' do |rec, acc, ctx|
      val = ctx.clipboard.dig(:dates, :content_date_range)
      acc << val if val
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

    # store IDs of associated boundwith records, where the actual holdings are attached.
    # this is a multi-valued field because a bib may have multiple copies, each associated
    # with a different boundwith record (a few such cases do exist).
    # we use this to pass to the Availability API.
    to_field 'bound_with_ids_a' do |rec, acc|
      acc.concat(pennlibmarc.get_bound_with_id_values(rec))
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

  def pennlibmarc
    @code_mappings ||= PennLib::CodeMappings.new(Rails.root.join('config').join('translation_maps'))
    @pennlibmarc ||= PennLib::Marc.new(@code_mappings)
  end

  def define_id
    to_field "id", trim(extract_marc("001"), :first => true) do |rec, acc, context|
      acc.map! { |id| "FRANKLIN_#{id}" }

      # we do this check in the first 'id' field so that it happens early
      if pennlibmarc.is_boundwith_record(rec)
        context.skip!("Skipping boundwith record #{acc.first}")
      end
    end
  end

  def define_mms_id
    to_field 'alma_mms_id', trim(extract_marc('001'), :first => true)
  end

  def define_access_facet
    to_field "access_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_access_values(rec))
    end
  end

  def define_oclc_id
    to_field 'oclc_id' do |rec, acc|
      acc.concat(pennlibmarc.get_oclc_id_values(rec))
    end
  end

  def get_cluster_id(rec)
    pennlibmarc.get_oclc_id_values(rec).first || begin
      id = rec.fields('001').take(1).map(&:value).first
      digest = Digest::MD5.hexdigest(id)
      # first 16 hex digits = first 8 bytes. construct an int out of that hex str.
      digest[0,16].hex
    end
  end

  def define_cluster_id
    to_field 'cluster_id' do |rec, acc|
      acc << get_cluster_id(rec)
    end
  end

  def define_grouped_id
    to_field 'grouped_id', trim(extract_marc('001'), :first => true) do |rec, acc, context|
      oclc_ids = pennlibmarc.get_oclc_id_values(rec)
      acc.map! { |id|
        if oclc_ids.size > 1
          puts 'Warning: Multiple OCLC IDs found, using the first one'
        end
        oclc_id = oclc_ids.first
        prefix = oclc_id.present? ? "#{oclc_id}!" : ''
        "#{prefix}FRANKLIN_#{id}"
      }
    end
  end

  def define_record_source_id
    to_field 'record_source_id' do |rec, acc|
      acc << RecordSource::PENN
    end
  end

  def define_record_source_facet
    to_field 'record_source_f' do |rec, acc|
      acc << 'Penn'
    end
  end

  def define_full_text_link_text_a
    to_field 'full_text_link_text_a' do |rec, acc|
      result = pennlibmarc.get_full_text_link_values(rec)
      if result.present?
        acc << result.to_json
      end
    end
  end

end
