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
    end

    def method_missing(*args)
      @record.send(*args)
    end

    def each
      @valid_tag_regex ||= /^\d\d\d$/
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

      if defined? JRUBY_VERSION
        # 'store' overrides existing settings, 'provide' does not
        store 'reader_class_name', "Traject::Marc4JReader"
        store 'solr_writer.thread_pool', 4
        store 'processing_thread_pool', 4
      end

      store 'solr_writer.commit_on_close', false

    end

    pennlibmarc = PennLib::Marc.new(Rails.root.join('indexing'))

    to_field "id", trim(extract_marc("001"), :first => true)

    to_field 'marcrecord_xml_stored_single', get_plain_marc_xml

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

    to_field "format_f_stored_single", get_format

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

    to_field 'title' do |rec, acc|
      acc.concat(pennlibmarc.get_title_values(rec))
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

    to_field 'recently_added_ssort' do |rec, acc|
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

    # URL Fields

    notfulltext = /abstract|description|sample text|table of contents|/i

    to_field('url_fulltext_display_a') do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '0'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '2'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          unless notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
    end

    # Very similar to url_fulltext_display. Should DRY up.
    to_field 'url_suppl_display_a' do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '2'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '0'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          if notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
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

  end
end
