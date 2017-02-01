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

  # returns enumerable of the subfields we care about for 655
  def subfields_for_655(record)
    record.fields('655').flat_map do |field|
      field.find_all { |sf| ! %W{0 2 5 c}.member?(sf.code) }
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
    to_field 'marc_xml', get_plain_marc_xml
    to_field "text_search", extract_all_marc_values do |r, acc|
      acc.unshift(r['001'].try(:value))
      acc.replace [acc.join(' ')] # turn it into a single string
    end

    to_field "access_f_stored" do |rec, acc|
      acc.concat(pennlibmarc.get_access_values(rec))
    end

    to_field "format_f_stored_single", get_format

    to_field "author_f", extract_marc(%W{
      100abcdjq
      110abcdjq
      700abcdjq
      710abcdjq
      800abcdjq
      810abcdjq
      111abcen
      711abcen
      811abcen
    }.join(':'), :trim_punctuation => true)

    to_field 'subject_f_stored' do |rec, acc|
      pennlibmarc.get_subject_facet_values(rec).each do |facet|
        acc << facet
      end
    end

    to_field 'subject_search' do |rec, acc|
      pennlibmarc.get_subject_search_values(rec).each do |facet|
        acc << facet
      end
    end

    to_field 'subject_xfacet' do |rec, acc|
      pennlibmarc.get_subject_xfacet_values(rec).each do |facet|
        acc << facet
      end
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

    # Title fields

    to_field 'title_search' do |rec, acc|
      acc.concat(pennlibmarc.get_title_search_values(rec))
    end

    to_field 'author_search' do |rec, acc|
      acc.concat(pennlibmarc.get_author_search_values(rec))
    end

    to_field 'author_a' do |rec, acc|
      acc.concat(pennlibmarc.get_author_values(rec))
    end

    to_field 'title' do |rec, acc|
      acc.concat(pennlibmarc.get_title_values(rec))
    end

    to_field 'standardized_title_a' do |rec, acc|
      acc.concat(pennlibmarc.get_standardized_title_values(rec))
    end

    to_field 'title_xfacet',
      extract_marc(%W{
        245abnps
        130#{ATOZ}
        240abcdefgklmnopqrs
        210ab
        222ab
        242abnp
        243abcdefgklmnopqrs
        246abcdefgnp
        247abcdefgnp
      }.join(':')) do |r, acc|
      acc.map! { |v| references(v) }
    end

    to_field 'title_ssort', marc_sortable_title

    # Author fields

    to_field 'author_xfacet', extract_marc("100abcegqu:110abcdegnu:111acdegjnqu") do |r, acc|
      acc.map! { |v| references(v) }
    end

    # JSTOR isn't an author. Try to not use it as one
    to_field 'author_ssort', marc_sortable_author

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

    to_field 'pub_date_isort_stored', marc_publication_date

    to_field "isbn_isxn_stored",  extract_marc('020az', :separator=>nil) do |rec, acc|
      orig = acc.dup
      acc.map!{|x| StdNum::ISBN.allNormalizedValues(x)}
      acc << orig
      acc.flatten!
      acc.uniq!
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
