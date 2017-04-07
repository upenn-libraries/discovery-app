# frozen_string_literal: true

require 'nokogiri'

module PennLib

  # Constants for Alma's MARC enrichment
  module EnrichedMarc
    # terminology follows the Publishing Profile screen
    TAG_HOLDING = 'hld'
    TAG_ITEM = 'itm'
    TAG_ELECTRONIC_INVENTORY = 'prt'
    TAG_DIGITAL_INVENTORY = 'dig'

    # these are 852 subfield codes; terminology comes from MARC spec
    SUB_HOLDING_SHELVING_LOCATION = 'c'
    SUB_HOLDING_SEQUENCE_NUMBER = '8'
    SUB_HOLDING_CLASSIFICATION_PART = 'h'
    SUB_HOLDING_ITEM_PART = 'i'

    SUB_ITEM_CURRENT_LOCATION = 'g'
    SUB_ITEM_CURRENT_LIBRARY = 'f'
    SUB_ITEM_CALL_NUMBER_TYPE = 'h'
    SUB_ITEM_CALL_NUMBER = 'i'

    SUB_ELEC_PORTFOLIO_PID = 'a'
    SUB_ELEC_ACCESS_URL = 'b'
    SUB_ELEC_COLLECTION_NAME = 'c'
    SUB_ELEC_COVERAGE = 'g'
  end

  # Class for doing extraction and processing on MARC::Record objects.
  # This is intended to be used in both indexing code and front-end templating code
  # (since MARC is stored in Solr). As such, there should NOT be any traject-specific
  # things here.
  #
  # For a slight performance increase (~5%?) we use frozen_string_literal for immutable strings.
  #
  # Method naming conventions:
  #
  # *_values = indicates method returns an Array of values
  #
  # *_display = indicates method is intended to be used for
  # individual record view (we should name things more meaningfully, according to
  # the logic by which the values are generated, but I don't always know what this
  # logic is, necessarily - JC)
  #
  class Marc

    include BlacklightSolrplugins::Indexer

    attr_accessor :path_to_lookup_files

    def initialize(path_to_lookup_files)
      @path_to_lookup_files = path_to_lookup_files
    end

    def current_year
      @current_year ||= Date.today.year
    end

    # block should return a hash to be merged into the hash that we're building
    def load_xml_lookup_file(filename, xpath_expr, &block)
      lookup = {}
      doc = Nokogiri::XML(File.open(Pathname.new(path_to_lookup_files) + filename))
      doc.xpath(xpath_expr).each do |element|
        lookup.merge! block.call(element)
      end
      lookup
    end

    def relator_codes
      @relator_codes ||= load_xml_lookup_file("relatorcodes.xml", "/relatorcodes/relator") do |element|
          { element['code'] => element.text }
      end
    end

    def locations
      @locations ||= load_xml_lookup_file("locations.xml", "/locations/location") do |element|
        struct = element.element_children.map { |c| [c.name, c.text] }.reduce(Hash.new) do |acc, rec|
          acc[rec[0]] = rec[1]
          acc
        end
        { element['location_code'] =>  struct }
      end
    end

    def loc_classifications
      @loc_classifications ||= load_xml_lookup_file("ClassOutline.xml", "/list/class") do |element|
        { element['value'] => element.text }
      end
    end

    def dewey_classifications
      @dewey_classifications ||= load_xml_lookup_file("DeweyClass.xml", "/list/class") do |element|
        { element['value'] => element.text }
      end
    end

    def languages
      @languages ||= load_xml_lookup_file("languages2.xml", "/languages/lang") do |element|
        { element['code'] => element.text }
      end
    end

    def trim_trailing_colon(s)
      s.sub(/\s*:\s*$/, '')
    end

    def trim_trailing_semicolon(s)
      s.sub(/\s*;\s*$/, '')
    end

    def trim_trailing_equal(s)
      s.sub(/=$/, '')
    end

    def trim_trailing_slash(s)
      s.sub(/\s*\/\s*$/, '')
    end

    def trim_trailing_comma(s)
      s.sub(/\s*,\s*$/, '')
    end

    def trim_trailing_period(s)
      if s.end_with?('etc.') || s =~ /(^|[^a-zA-Z])[A-Z]\.$/
        s
      else
        s.sub(/\.\s*$/, '')
      end
    end

    def normalize_space(s)
      s.strip.gsub(/\s{2,}/, ' ')
    end

    # this logic matches substring-before in XSLT: if no match for sub, returns an empty string
    def substring_before(s, sub)
      s.scan(sub).present? ? s.split(sub, 2)[0] : ''
    end

    # this logic matches substring-after in XSLT: if no match for sub, returns an empty string
    def substring_after(s, sub)
      s.scan(sub).present? ? s.split(sub, 2)[1] : ''
    end

    def join_and_trim_whitespace(array)
      normalize_space(array.join(' '))
    end

    # join subfield values together (as selected using passed-in block)
    def join_subfields(field, &block)
      field.select { |v| block.call(v) }.map(&:value).select { |v| v.present? }.join(' ')
    end

    # this is used for filtering in a lots of places
    # returns a lambda that can be passed to Enumerable#select
    # using the & syntax
    def subfield_not_6_or_8
      @subfield_not_6_or_8 ||= lambda { |subfield|
        !%w{6 8}.member?(subfield.code)
      }
    end

    # returns a lambda checking if passed-in subfield's code
    # is a member of array
    def subfield_in(array)
      lambda { |subfield| array.member?(subfield.code) }
    end

    # returns a lambda checking if passed-in subfield's code
    # is NOT a member of array
    def subfield_not_in(array)
      lambda { |subfield| !array.member?(subfield.code) }
    end

    # common case of wanting to extract subfields as selected by passed-in block,
    # from 880 datafield that has a particular subfield 6 value
    # @param subf6_value [String|Array] either a single str value to look for in sub6 or an array of them
    # @param block [Proc] takes a subfield as argument, returns a boolean
    def get_880(rec, subf6_value, &block)
      regex_value = subf6_value
      if subf6_value.is_a?(Array)
        regex_value = "(#{subf6_value.join('|')})"
      end

      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^#{regex_value}/) }
          .map do |field|
        field.select { |sf| block.call(sf) }.map(&:value).join(' ')
      end
    end

    # common case of wanting to extract all the subfields besides 6 or 8,
    # from 880 datafield that has a particular subfield 6 value
    def get_880_subfield_not_6_or_8(rec, subf6_value)
      get_880(rec, subf6_value) do |sf|
        !%w{6 8}.member?(sf.code)
      end
    end

    # returns the non-6,8 subfields from a datafield and its 880 link
    def get_datafield_and_880(rec, tag)
      acc = []
      acc += rec.fields(tag).map do |field|
        join_subfields(field, &subfield_not_in(%w{6 8}))
      end
      acc += get_880_subfield_not_6_or_8(rec, tag)
      acc
    end

    # returns true if field's subfield 6 has a value that matches
    # passed-in regex
    def has_subfield6_value(field, regex)
      field.any? { |sf| sf.code == '6' && sf.value =~ regex }
    end

    # for a string 's', return a hash of ref_type => Array of references,
    # where a reference is a String or a Hash representing a multipart string
    def get_subject_references(s)
      # TODO: just simple test data for now; hook up to actual cross ref data
      case s
        when 'Cyberspace'
          { 'see_also' => [ 'Internet', 'Computer networks' ] }
        when 'Internet'
          { 'see_also' => [ 'Cyberspace', 'Computer networks' ] }
        when 'Computer networks'
          { 'see_also' => [ 'Cyberspace', 'Internet' ] }
        # one way
        when 'Programming Languages'
          { 'use_instead' => [ 'Computer programming' ] }
      end
    end

    def subject_codes
      @subject_codes ||= %w(600 610 611 630 650 651)
    end

    def is_subject_field(field)
      subject_codes.member?(field.tag) && %w(0 2 4).member?(field.indicator2)
    end

    # if double_dash is true, then some subfields are joined together with --
    def join_subject_parts(field, double_dash: false)
      parts = field.find_all(&subfield_in(['a'])).map(&:value)
                  .select { |v| v !~ /^%?(PRO|CHR)/ }
      parts += field.find_all(&subfield_not_in(%w{a 6 5})).map do |sf|
        (double_dash && !%w{b c d q t}.member?(sf.code) ? ' -- ' : ' ') + sf.value
      end.map(&:strip)
      parts.join(' ')
    end

    def get_subject_facet_values(rec)
      rec.fields.find_all { |f| is_subject_field(f) }.map do |field|
        just_a = nil
        if field.any? { |sf| sf.code == 'a' } && field.any? { |sf| sf.code != 'a' }
          just_a = field.find_all(&subfield_in(%w{a})).map(&:value)
              .select { |v| v !~ /^%?(PRO|CHR)/ }.join(' ')
        end
        [ join_subject_parts(field), just_a ].compact.map{ |v| trim_trailing_period(v) }
      end.flatten(1).select { |v| v.present? }
    end

    def get_subject_xfacet_values(rec)
      rec.fields.find_all { |f| is_subject_field(f) }
          .map { |f| join_subject_parts(f, double_dash: true) }
          .map { |v| trim_trailing_period(v) }
          .map { |s| references(s, refs: get_subject_references(s)) }
    end

    def subject_search_tags
      @subject_search_tags ||= %w{541 561 600 610 611 630 650 651 653}
    end

    def is_subject_search_field(field)
      if subject_search_tags.member?(field.tag) || field.tag.start_with?('69')
        true
      elsif field.tag == '880'
        sub6 = (field.find_all { |sf| sf.code == '6' }.map(&:value).first || '')[0..2]
        subject_search_tags.member?(sub6) || sub6.start_with?('69')
      else
        false
      end
    end

    def get_subject_search_values(rec)
      # this has been completely migrated
      rec.fields.find_all { |f| is_subject_search_field(f) }
          .map do |field|
            subj = []
            field.each do |sf|
              if sf.code == 'a'
                subj << " #{sf.value.gsub(/^%?(PRO|CHR)/, '').gsub(/\?$/, '')}"
              elsif sf.code == '4'
                subj << "#{sf.value}, #{relator_codes[sf.value]}"
              elsif !%w{a 4 5 6 8}.member?(sf.code)
                subj << " #{sf.value}"
              end
            end
            join_and_trim_whitespace(subj) if subj.present?
      end.compact
    end

    # @returns [Array] of string field tags to examine for subjects
    def subject_600s
      @subject_600s ||= %w{600 610 611 630 650 651}
    end

    def get_subjects_from_600s_and_800(rec, indicator2)
      acc = []
      if %w{0 1 2}.member?(indicator2)
        # Subjects, Childrens subjects, and Medical Subjects all share this code
        acc += rec.fields
                   .select { |f| subject_600s.member?(f.tag) ||
                      (f.tag == '800' && has_subfield6_value(f, /^(#{subject_600s.join('|')})/)) }
                   .select { |f| f.indicator2 == indicator2 }
                   .map do |field|
          value_for_link = join_subfields(field, &subfield_not_in(%w{6 8 2 e w}))
          sub_with_hyphens = field.select(&subfield_not_in(%w{6 8 2 e w})).map do |sf|
            pre = !%w{a b c d p q t}.member?(sf.code) ? ' -- ' : ' '
            pre + sf.value + (sf.code == 'p' ? '.' : '')
          end.join(' ')
          eandw_with_hyphens = field.select(&subfield_in(%w{e w})).map do |sf|
            ' -- ' + sf.value
          end.join(' ')
          if sub_with_hyphens.present?
            {
                value: sub_with_hyphens,
                value_for_link: value_for_link,
                value_append: eandw_with_hyphens,
                link_type: 'subject_xfacet'
            }
          end
        end.compact
      elsif indicator2 == '4'
        # Local subjects
        acc += rec.fields(subject_600s)
                   .select { |f| f.indicator2 == '4' }
                   .map do |field|
          suba = field.select(&subfield_in(%w{a}))
                     .select { |sf| sf.value !~ /^%?(PRO|CHR)/ }
                     .map(&:value).join(' ')
          sub_oth = field.select(&subfield_not_in(%w{a 6 8})).map do |sf|
            pre = !%w{b c d p q t}.member?(sf.code) ? ' -- ' : ' '
            pre + sf.value + (sf.code == 'p' ? '.' : '')
          end
          subj_display = [ suba, sub_oth ].join(' ')
          sub_oth_no_hyphens = join_subfields(field, &subfield_not_in(%w{a 6 8}))
          subj_search = [ suba, sub_oth_no_hyphens ].join(' ')
          if subj_display.present?
            {
                value: subj_display,
                value_for_link: subj_search,
                link_type: 'subject_search'
            }
          end
        end.compact
      end
      acc
    end

    def get_subject_display(rec)
      get_subjects_from_600s_and_800(rec, '0')
    end

    def get_children_subject_display(rec)
      get_subjects_from_600s_and_800(rec, '1')
    end

    def get_medical_subject_display(rec)
      get_subjects_from_600s_and_800(rec, '2')
    end

    def get_local_subject_display(rec)
      get_subjects_from_600s_and_800(rec, '4')
    end

    def get_format(rec)
      acc = []

      format_code = get_format_from_leader(rec)
      f008 = rec.fields('008').map { |field| field.value }.first || ''
      f007 = rec.fields('007').map { |field| field.value }
      f260press = rec.fields('260').any? do |field|
        field.select { |sf| sf.code == 'b' && sf.value =~ /press/i }.any?
      end
      # first letter of every 006
      f006firsts = rec.fields('006').map do |field|
        field.value[0]
      end
      f245k = rec.fields('245').flat_map do |field|
        field.select { |sf| sf.code == 'k' }.map { |sf| sf.value }
      end
      f245h = rec.fields('245').flat_map do |field|
        field.select { |sf| sf.code == 'h' }.map { |sf| sf.value }
      end
      f337a = rec.fields('337').flat_map do |field|
        field.select { |sf| sf.code == 'a' }.map { |sf| sf.value }
      end
      call_nums = rec.fields(EnrichedMarc::TAG_HOLDING).map do |field|
        # h gives us the 'Classification part' which contains strings like 'Microfilm'
        join_subfields(field, &subfield_in(%w(h i)))
      end
      locations = get_specific_location_values(rec)

      if locations.any? { |loc| loc =~ /manuscripts/i }
        acc << 'Manuscript'
      elsif locations.any? { |loc| loc =~ /archives/i } &&
          locations.none? { |loc| loc =~ /cajs/i } &&
          locations.none? { |loc| loc =~ /nursing/i }
        acc << 'Archive'
      elsif locations.any? { |loc| loc =~ /micro/i } ||
          f245h.any? { |val| val =~ /micro/i } ||
          call_nums.any? { |val| val =~ /micro/i } ||
          f337a.any? { |val| val =~ /microform/i }
        acc << 'Microformat'
      else
        # these next 4 can have this format plus ONE of the formats down farther below
        if rec.fields('502').any? && format_code == 'tm'
          acc << 'Thesis/Dissertation'
        end
        if rec.fields('111').any? || rec.fields('711').any?
          acc << 'Conference/Event'
        end
        if (!%w{c d i j}.member?(format_code[0])) && %w{f i o}.member?(f008[28]) && (!f260press)
          acc << 'Government document'
        end
        if format_code == 'as' && (f008[21] == 'n' || f008[22] == 'e')
          acc << 'Newspaper'
        end

        # only one of these
        if format_code.end_with?('i') || (format_code == 'am' && f006firsts.member?('m') && f006firsts.member?('s'))
          acc << 'Database/Website'
        elsif %w(aa ac am tm).member?(format_code) &&
            f245k.none? { |v| v =~ /kit/i } &&
            f245h.none? { |v| v =~ /micro/i }
          acc << 'Book'
        elsif %w(ca cb cd cm cs dm).member?(format_code)
          acc << 'Musical score'
        elsif format_code.start_with?('e') || format_code == 'fm'
          acc << 'Map/Atlas'
        elsif format_code == 'gm'
          if f007.any? { |v| v.start_with?('v') }
            acc << 'Video'
          elsif f007.any? { |v| v.start_with?('g') }
            acc << 'Projected graphic'
          else
            acc << 'Video'
          end
        elsif %w(im jm jc jd js).member?(format_code)
          acc << 'Sound recording'
        elsif %w(km kd).member?(format_code)
          acc << 'Image'
        elsif format_code == 'mm'
          acc << 'Datafile'
        elsif %w(as gs).member?(format_code)
          acc << 'Journal/Periodical'
        elsif format_code.start_with?('r')
          acc << '3D object'
        else
          acc << 'Other'
        end
      end
      acc
    end

    # returns two-char format code from MARC leader, representing two fields:
    # "Type of record" and "Bibliographic level"
    def get_format_from_leader(rec)
      rec.leader[6..7]
    end

    def get_format_display(rec)
      results = []
      results += rec.fields('300').map do |field|
        join_subfields(field, &subfield_not_in(%w{3 6 8}))
      end
      results += rec.fields(%w{254 255 310 342 352 362}).map do |field|
        join_subfields(field, &subfield_not_in(%w{6 8}))
      end
      results += rec.fields('340').map do |field|
        join_subfields(field, &subfield_not_in(%w{0 2 6 8}))
      end
      results += rec.fields('880').map do |field|
        if has_subfield6_value(field,/^300/)
          join_subfields(field, &subfield_not_in(%w{3 6 8}))
        elsif has_subfield6_value(field, /^(254|255|310|342|352|362)/)
          join_subfields(field, &subfield_not_in(%w{6 8}))
        elsif has_subfield6_value(field, /^340/)
          join_subfields(field, &subfield_not_in(%w{0 2 6 8}))
        else
          []
        end
      end
      results.select { |value| value.present? }
    end

    def get_access_values(rec)
      acc = rec.map do |f|
        case f.tag
          when EnrichedMarc::TAG_HOLDING
            'At the library'
          when EnrichedMarc::TAG_ELECTRONIC_INVENTORY
            'Online'
        end
      end.compact
      acc += rec.fields('856')
                 .select { |f| f.indicator1 == '4' && f.indicator2 != '2' }
                 .flat_map do |field|
        subz = join_subfields(field, &subfield_in(%w{z}))
        field.find_all(&subfield_in(%w{u})).map do |sf|
          if !subz.include?('Finding aid') && sf.value.include?('hdl.library.upenn.edu')
            'Online'
          end
        end.compact
      end
      acc.uniq
    end

    # examines a 1xx datafield and constructs a string out of select
    # subfields, including expansion of 'relator' code
    def get_name_1xx_field(field)
      s = field.map do |sf|
        if(! %W{4 6 8}.member?(sf.code))
          " #{sf.value}"
        elsif sf.code == '4'
          ", #{relator_codes[sf.value]}"
        end
      end.compact.join
      s2 = s + (!%w(. -).member?(s[-1]) ? '.' : '')
      normalize_space(s2)
    end

    def get_series_8xx_field(field)
      s = field.map do |sf|
        if(! %W{4 5 6 8}.member?(sf.code))
          " #{sf.value}"
        elsif sf.code == '4'
          ", #{relator_codes[sf.value]}"
        end
      end.compact.join
      s2 = s + (!%w(. -).member?(s[-1]) ? '.' : '')
      normalize_space(s2)
    end

    def get_series_4xx_field(field)
      s = field.map do |sf|
        if(! %W{4 6 8}.member?(sf.code))
          " #{sf.value}"
        elsif sf.code == '4'
          ", #{relator_codes[sf.value]}"
        end
      end.compact.join
      s2 = s + (!%w(. -).member?(s[-1]) ? '.' : '')
      normalize_space(s2)
    end

    def get_publication_values(rec)
      acc = []
      rec.fields('245').each do |field|
        field.find_all { |sf| sf.code == 'f' }
            .map(&:value)
            .each { |value| acc << value }
      end
      added_2xx = false
      rec.fields(%w{260 261 262}).take(1).each do |field|
        results = field.find_all { |sf| sf.code != '6' }
                      .map(&:value)
        acc << join_and_trim_whitespace(results)
        added_2xx = true
      end
      if(!added_2xx)
        sf_ab264 = rec.fields.select { |field| field.tag == '264' && field.indicator2 == '1' }
                       .take(1)
                       .flat_map do |field|
          field.find_all(&subfield_in(%w{a b})).map(&:value)
        end

        sf_c264_1 = rec.fields.select { |field| field.tag == '264' && field.indicator2 == '1' }
                        .take(1)
                        .flat_map do |field|
          field.find_all(&subfield_in(['c']))
              .map(&:value)
              .select { |value| value =~ /\d\d\d\d/ }
        end

        sf_c264_4 = rec.fields.select { |field| field.tag == '264' && field.indicator2 == '4' }
                        .take(1)
                        .flat_map do |field|
          field.find_all { |sf| sf.code == 'c' }
              .map { |sf| (sf_c264_1.present? ? ', ' : '') + sf.value }
        end

        acc << [sf_ab264, sf_c264_1, sf_c264_4].join(' ')
      end
      acc.map!(&:strip).select!(&:present?)
      acc
    end

    def get_publication_display(rec)
      acc = []
      rec.fields('245').take(1).each do |field|
        field.find_all { |sf| sf.code == 'f' }
            .map(&:value)
            .each { |value| acc << value }
      end
      rec.fields(%w{260 261 262}).take(1).each do |field|
        acc << join_subfields(field, &subfield_not_6_or_8)
      end
      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(260|261|262)/) }
          .take(1)
          .each do |field|
        acc << join_subfields(field, &subfield_not_6_or_8)
      end
      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^245/) }
          .each do |field|
        acc << join_subfields(field, &subfield_in(['f']))
      end
      acc
    end

    # used to determine whether to include faceted publication values
    # as part of record display
    def has_264_with_a_or_b(rec)
      rec.fields('264')
          .select { |f| f.indicator2 == '1' }
          .take(1)
          .any? { |f| f.any?(&subfield_in(%w{a b})) }
    end

    def get_language_values(rec)
      rec.fields('008').map do |field|
        lang_code = field.value[35..37]
        if lang_code
          languages[lang_code]
        end
      end.compact
    end

    # fieldname = name of field in the locations data structure to use
    def holdings_location_mappings(rec, display_fieldname)
      acc = []
      rec.fields(EnrichedMarc::TAG_HOLDING).each do |field|
        field.find_all { |sf| sf.code == EnrichedMarc::SUB_HOLDING_SHELVING_LOCATION }
            .map { |sf|
          # sometimes "happening locations" are mistakenly
          # used in holdings records. that's a data problem that should be fixed.
          # here, if we encounter a code we can't map, we ignore it, for faceting purposes.
          if locations[sf.value].present?
            locations[sf.value][display_fieldname]
          end
        }.select { |value| value.present? }.each { |value| acc << value }
      end
      acc.uniq
    end

    def get_library_values(rec)
      holdings_location_mappings(rec, 'library')
    end

    def get_specific_location_values(rec)
      holdings_location_mappings(rec, 'specific_location')
    end

    def publication_date_digits(rec)
      rec.fields('008').map { |field| field.value[7,4] }
          .select { |year| year.present? }
          .map { |year| year.gsub(/\D/, '0') }
    end

    def get_publication_date_values(rec)
      publication_date_digits(rec)
          .select { |year| year =~ /^[1-9][0-9]/ && current_year + 15 > year.to_i }
          .map { |year| year[0, 3] + '0s' }
    end

    def get_publication_date_sort_values(rec)
      publication_date_digits(rec)
    end

    def get_classification_values(rec)
      acc = []
      # not sure whether it's better to use 'item' or 'holding' records here.
      # we use 'item' only because it has a helpful call number type subfield,
      # which the holding doesn't.
      rec.fields(EnrichedMarc::TAG_ITEM).each do |item|
        cn_type = item.find_all { |sf| sf.code == EnrichedMarc::SUB_ITEM_CALL_NUMBER_TYPE }.map(&:value).first

        results = item.find_all { |sf| sf.code == EnrichedMarc::SUB_ITEM_CALL_NUMBER }
                      .map(&:value)
                      .select { |call_num| call_num.present? }
                      .map { |call_num| call_num[0] }
                      .compact

        results.each do |letter|
          verbose = nil
          case cn_type
            when '0'
              verbose = loc_classifications[letter]
            when '1'
              verbose = dewey_classifications[letter]
              letter = letter + '00'
          end
          if verbose
            acc << [ letter, verbose ].join(' - ')
          end
        end
      end
      acc.uniq
    end

    def get_genre_values(rec)
      acc = []

      is_manuscript = rec.fields(EnrichedMarc::TAG_ITEM).any? do |item|
        loc = item[EnrichedMarc::SUB_ITEM_CURRENT_LOCATION]
        locations[loc].present? && (locations[loc]['specific_location'] =~ /manuscript/)
      end

      if rec['007'].try { |r| r.value.start_with?('v') } || is_manuscript
        genres = rec.fields('655').map do |field|
          field.find_all(&subfield_not_in(%w{0 2 5 c}))
              .map(&:value)
              .join(' ')
        end
        genres.each { |genre| acc << genre }
      end
      acc
    end

    def get_genre_search_values(rec)
      rec.fields('655').map do |field|
        join_subfields(field, &subfield_not_in(%w{0 2 5 c}))
      end
    end

    def get_genre_display(rec, should_link)
      rec.fields
          .select { |f| f.tag == '655' || (f.tag == '880' && has_subfield6_value(f, /655/)) }
          .map do |field|
        sub_with_hyphens = field.find_all(&subfield_not_in(%w{0 2 5 6 8 c e w})).map do |sf|
          sep = ! %w{a b }.member?(sf.code) ? ' -- ' : ' '
          sep + sf.value
        end.join
        eandw_with_hyphens = field.find_all(&subfield_in(%w{e w})).join(' -- ')
        { value: sub_with_hyphens, value_append: eandw_with_hyphens, link: should_link, link_type: 'genre_search' }
      end
    end

    def get_title_values(rec)
      acc = []
      rec.fields('245').take(1).each do |field|
        a_or_k = field.find_all(&subfield_in(%w{a k}))
                     .map { |sf| trim_trailing_comma(trim_trailing_slash(sf.value).rstrip) }
                     .first || ''
        joined = field.find_all(&subfield_in(%w{b n p}))
                     .map{ |sf| trim_trailing_slash(sf.value) }
                     .join(' ')

        apunct = a_or_k[-1]
        hpunct = field.find_all { |sf| sf.code == 'h' }
                     .map{ |sf| sf.value[-1] }
                     .first
        punct = if [apunct, hpunct].member?('=')
                  '='
                else
                  [apunct, hpunct].member?(':') ? ':' : nil
                end

        acc << [ trim_trailing_colon(trim_trailing_equal(a_or_k)), punct, joined ]
              .select(&:present?).join(' ')
      end
      acc
    end

    def get_title_880_values(rec)
      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^245/) }
          .map do |field|
        suba_value = field.find_all(&subfield_in(%w{a})).first.try(:value)
        subk_value = field.find_all(&subfield_in(%w{k})).first.try(:value) || ''
        title_with_slash = suba_value.present? ? suba_value : (subk_value + ' ')
        title_ak = trim_trailing_comma(join_and_trim_whitespace([ trim_trailing_slash(title_with_slash) ]))

        subh = join_and_trim_whitespace(field.find_all(&subfield_in(%w{h})).map(&:value))

        apunct = title_ak[-1]
        hpunct = subh[-1]

        punct = if [apunct, hpunct].member?('=')
                  '='
                else
                  [apunct, hpunct].member?(':') ? ':' : nil
                end

        [ trim_trailing_equal(title_ak),
          punct,
          trim_trailing_slash(field.find_all(&subfield_in(%w{b})).first.try(:value) || ''),
          trim_trailing_slash(field.find_all(&subfield_in(%w{n})).first.try(:value) || ''),
          trim_trailing_slash(field.find_all(&subfield_in(%w{p})).first.try(:value) || '')
        ]
        .select { |value| value.present? }
        .join(' ')
      end
    end

    def separate_leading_bracket_into_prefix_and_filing_hash(s)
      if s.start_with?('[')
        { 'prefix' => '[', 'filing' => s[1..-1] }
      else
        { 'prefix' => '', 'filing' => s }
      end
    end

    def get_title_245(rec)
      rec.fields('245').take(1).map do |field|
        value = {}
        offset = (field.indicator2 == ' ' ? '0' : field.indicator2).to_i
        suba = join_subfields(field, &subfield_in(%w{a}))
        if offset > 0 && offset < 10
          part1 = suba[0..offset-1]
          part2 = suba[offset..-1]
          value = { 'prefix' => part1, 'filing' => part2 }
        else
          if suba.present?
            value = separate_leading_bracket_into_prefix_and_filing_hash(suba)
          else
            subk = join_subfields(field, &subfield_in(%w{k}))
            value = separate_leading_bracket_into_prefix_and_filing_hash(subk)
          end
        end
        value['filing'] = [ value['filing'], join_subfields(field, &subfield_in(%w{b n p})) ].join(' ')
        value
      end
    end

    def get_title_xfacet_values(rec)
      get_title_245(rec).map do |v|
        references(v)
      end
    end

    def get_title_sort_values(rec)
      get_title_245(rec).map do |v|
        v['prefix'] + v['filing']
      end
    end

    def get_title_1_search_main_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      rec.fields(%w{245 880}).map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{c 6 8 h})).map(&:value))
        end
      end.select { |v| v.present? }
    end

    def get_title_1_search_values(rec)
      get_title_1_search_main_values(rec)
    end

    def get_journal_title_1_search_values(rec)
      get_title_1_search_main_values(rec, format_filter: true)
    end

    def title_2_search_main_tags
      @title_2_search_main_tags ||= %w{130 210 240 245 246 247 440 490 730 740 830}
    end

    def title_2_search_aux_tags
      @title_2_search_aux_tags ||= %w{773 774 780 785}
    end

    def title_2_search_7xx_tags
      @title_2_search_7xx_tags ||= %w{700 710 711}
    end

    def get_title_2_search_main_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      rec.fields(title_2_search_main_tags).map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{c 6 8})).map(&:value))
        end
      end.select { |v| v.present? }
    end

    def get_title_2_search_aux_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      rec.fields(title_2_search_aux_tags).map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{s t})).map(&:value))
        end
      end.select { |v| v.present? }
    end

    def get_title_2_search_7xx_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      rec.fields(title_2_search_7xx_tags).map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_in(%w{t})).map(&:value))
        end
      end.select { |v| v.present? }
    end

    def get_title_2_search_505_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      rec.fields('505')
          .select { |f| f.indicator1 == '0' && f.indicator2 == '0' }
          .map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_in(%w{t})).map(&:value))
        end
      end.select { |v| v.present? }
    end

    def get_title_2_search_800_values(rec, format_filter: false)
      format = get_format_from_leader(rec)
      acc = []
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^(130|210|240|245|246|247|440|490|730|740|830)/ } }
                 .map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{c 6 8 h})).map(&:value))
        end
      end.select { |v| v.present? }
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^(773|774|780|785)/ } }
                 .map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_in(%w{s t})).map(&:value))
        end
      end.select { |v| v.present? }
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^(700|710|711)/ } }
                 .map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_in(%w{t})).map(&:value))
        end
      end.select { |v| v.present? }
      acc += rec.fields('880')
                 .select { |f| f.indicator1 == '0' && f.indicator2 == '0' }
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^505/ } }
                 .map do |field|
        if !format_filter || format.end_with?('s')
          join_and_trim_whitespace(field.find_all(&subfield_in(%w{t})).map(&:value))
        end
      end.select { |v| v.present? }
      acc
    end

    def get_title_2_search_values(rec)
      get_title_2_search_main_values(rec) +
          get_title_2_search_aux_values(rec) +
          get_title_2_search_7xx_values(rec) +
          get_title_2_search_505_values(rec) +
          get_title_2_search_800_values(rec)
    end

    def get_journal_title_2_search_values(rec)
      get_title_2_search_main_values(rec, format_filter: true) +
          get_title_2_search_aux_values(rec, format_filter: true) +
          get_title_2_search_7xx_values(rec, format_filter: true) +
          get_title_2_search_505_values(rec, format_filter: true) +
          get_title_2_search_800_values(rec, format_filter: true)
    end

    # this gets called directly by ShowPresenter rather than via
    # Blacklight's show field definition plumbing, so we return a single string
    def get_title_display(rec)
      acc = []
      acc += rec.fields('245').map do |field|
        join_subfields(field, &subfield_not_in(%w{6 8}))
      end
      acc += get_880(rec, '245', &subfield_not_in(%w{6 8}))
                 .map { |value| " = #{value}" }
      acc.join(' ')
    end

    def author_creator_tags
      @author_creator_tags ||= %w{100 110}
    end

    def get_author_creator_values(rec)
      rec.fields(author_creator_tags).map do |field|
        get_name_1xx_field(field)
      end
    end

    def get_author_880_values(rec)
      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(100|110)/) }
          .map do |field|
        join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{4 6 8})).map(&:value))
      end
    end

    def get_author_creator_1_search_values(rec)
      acc = []
      acc += rec.fields(%w{100 110}).map do |field|
        pieces = field.map do |sf|
          if sf.code == 'a'
            after_comma = join_and_trim_whitespace([ trim_trailing_comma(substring_after(sf.value, ', ')) ])
            before_comma = substring_before(sf.value, ', ')
            " #{after_comma} #{before_comma}"
          elsif(! %W{a 4 6 8}.member?(sf.code))
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact
        value = join_and_trim_whitespace(pieces)
        if value.end_with?('.') || value.end_with?('-')
          value
        else
          value + '.'
        end
      end
      acc += rec.fields(%w{100 110}).map do |field|
        pieces = field.map do |sf|
          if(! %W{4 6 8}.member?(sf.code))
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact
        value = join_and_trim_whitespace(pieces)
        if value.end_with?('.') || value.end_with?('-')
          value
        else
          value + '.'
        end
      end
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^(100|110)/ } }
                 .map do |field|
        suba = field.find_all(&subfield_in(%w{a})).map do |sf|
          after_comma = join_and_trim_whitespace([ trim_trailing_comma(substring_after(sf.value, ',')) ])
          before_comma = substring_before(sf.value, ',')
          "#{after_comma} #{before_comma}"
        end.first
        oth = join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{6 8 a t})).map(&:value))
        [suba, oth].join(' ')
      end
      acc
    end

    def author_creator_2_tags
      @author_creator_2_tags ||= %w{100 110 111 400 410 411 700 710 711 800 810 811}
    end

    def get_author_creator_2_search_values(rec)
      acc = []
      acc += rec.fields(author_creator_2_tags).map do |field|
        pieces1 = field.map do |sf|
          if(! %W{4 5 6 8 t}.member?(sf.code))
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact
        value1 = join_and_trim_whitespace(pieces1)
        if value1.end_with?('.') || value1.end_with?('-')
          value1
        else
          value1 + '.'
        end

        pieces2 = field.map do |sf|
          if sf.code == 'a'
            after_comma = join_and_trim_whitespace([ trim_trailing_comma(substring_after(sf.value, ', ')) ])
            before_comma = substring_before(sf.value, ',')
            " #{after_comma} #{before_comma}"
          elsif(! %W{a 4 5 6 8 t}.member?(sf.code))
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact
        value2 = join_and_trim_whitespace(pieces2)
        if value2.end_with?('.') || value2.end_with?('-')
          value2
        else
          value2 + '.'
        end

        [ value1, value2 ]
      end.flatten(1)
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code =='6' && sf.value =~ /^(100|110|111|400|410|411|700|710|711|800|810|811)/ } }
                 .map do |field|
        value1 = join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{5 6 8 t})).map(&:value))

        suba = field.find_all(&subfield_in(%w{a})).map do |sf|
          after_comma = join_and_trim_whitespace([ trim_trailing_comma(substring_after(sf.value, ',')) ])
          before_comma = substring_before(sf.value, ',')
          "#{after_comma} #{before_comma}"
        end.first
        oth = join_and_trim_whitespace(field.find_all(&subfield_not_in(%w{5 6 8 a t})).map(&:value))
        value2 = [ suba, oth ].join(' ')

        [ value1, value2 ]
      end.flatten(1)
      acc
    end

    def get_author_creator_sort_values(rec)
      rec.fields(author_creator_tags).take(1).map do |field|
        join_subfields(field, &subfield_not_in(%w{468e}))
      end
    end

    def get_author_display(rec)
      acc = []
      rec.fields(%w{100 110}).each do |field|
        subf4 = get_subfield_4ew(field)
        author_parts = []
        field.each do |sf|
          if !%W{4 6 8 e w}.member?(sf.code)
            author_parts << sf.value
          end
        end
        acc << {
            value: author_parts.join(' '),
            value_append: subf4,
            link_type: 'author_creator_xfacet' }
      end
      rec.fields('880').each do |field|
        if has_subfield6_value(field, /^(100|110)/)
          subf4 = get_subfield_4ew(field)
          author_parts = []
          field.each do |sf|
            if !%W{4 6 8 e w}.member?(sf.code)
              author_parts << sf.value.gsub(/\?$/, '')
            end
          end
          acc << {
              value: author_parts.join(' '),
              value_append: subf4,
              link_type: 'author_creator_xfacet' }
        end
      end
      acc
    end

    def get_corporate_author_search_values(rec)
      rec.fields(%w{110 710 810}).map do |field|
        join_and_trim_whitespace(field.select(&subfield_in(%w{a b c d})).map(&:value))
      end
    end

    def get_standardized_title_values(rec)
      rec.fields(%w{130 240}).map do |field|
        results = field.find_all(&subfield_not_in(%W{6 8})).map(&:value)
        join_and_trim_whitespace(results)
      end
    end

    def get_standardized_title_display(rec)
      acc = []
      rec.fields(%w{130 240}).each do |field|
        title = join_subfields(field, &subfield_not_in(%W{6 8 e w}))
        title_param_value = join_subfields(field, &subfield_not_in(%W{5 6 8 e w}))
        title_append = get_title_extra(field)
        acc << {
            value: title,
            value_for_link: title_param_value,
            value_append: title_append,
            link_type: 'title_search' }
      end
      rec.fields('730')
          .select { |f| f.indicator1 == '' || f.indicator2 == '' }
          .select { |f| f.none? { |sf| sf.code == 'i'} }
          .each do |field|
        title = join_subfields(field, &subfield_not_in(%w{5 6 8 e w}))
        title_append = get_title_extra(field)
        acc << {
            value: title,
            value_append: title_append,
            link_type: 'title_search' }
      end
      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(130|240|730)/) }
          .select { |f| f.none? { |sf| sf.code == 'i'} }
          .each do |field|
        title = join_subfields(field, &subfield_not_in(%w{5 6 8 e w}))
        title_append = get_title_extra(field)
        acc << {
            value: title,
            value_append: title_append,
            link_type: 'title_search' }
      end
      acc
    end

    def get_edition_values(rec)
      rec.fields('250').take(1).map do |field|
        results = field.find_all(&subfield_not_in(%w{6 8})).map(&:value)
        join_and_trim_whitespace(results)
      end
    end

    def get_edition_display(rec)
      acc = []
      acc += rec.fields('250').map do |field|
        join_subfields(field, &subfield_not_in(%W{6 8}))
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^250/)}
                 .map do |field|
        join_subfields(field, &subfield_not_in(%W{6 8}))
      end
      acc
    end

    def get_conference_values(rec)
      rec.fields('111').map do |field|
        get_name_1xx_field(field)
      end
    end

    def get_conference_search_values(rec)
      rec.fields(%w{111 711 811}).map do |field|
        join_and_trim_whitespace(field.select(&subfield_in(%w{a c d e})).map(&:value))
      end
    end

    def get_conference_display(rec)
      results = rec.fields(%w{111 711})
          .select{ |f| ['', ' '].member?(f.indicator2) }
          .map do |field|
        conf = ''
        if field.none? { |sf| sf.code == 'i' }
          conf = join_subfields(field, &subfield_not_in(%w{4 5 6 8 e j w}))
        end
        conf_append = join_subfields(field, &subfield_in(%w{e j w}))
        { value: conf, value_append: conf_append, link_type: 'author_creator_xfacet' }
      end
      results += rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(111|711)/) }
          .select { |f| f.none? { |sf| sf.code == 'i' } }
          .map do |field|
        conf = join_subfields(field, &subfield_not_in(%w{4 5 6 8 e j w}))
        conf_extra = join_subfields(field, &subfield_in(%w{4 e j w}))
        { value: conf, value_append: conf_extra, link_type: 'author_creator_xfacet' }
      end
      results
    end

    def get_series_values(rec)
      acc = []
      added_8xx = false
      rec.fields(%w{800 810 811 830}).take(1).each do |field|
        acc << get_series_8xx_field(field)
        added_8xx = true
      end
      if !added_8xx
        rec.fields(%w{400 410 411 440 490}).take(1).map do |field|
          acc << get_series_4xx_field(field)
        end
      end
      acc
    end

    def series_tags
      @series_tags ||= %w{800 810 811 830 400 411 440 490}
    end

    def get_series_display(rec)
      acc = []

      tags_present = series_tags.select { |tag| rec[tag].present? }

      if %w{800 810 811 400 410 411}.member?(tags_present.first)
        rec.fields(tags_present.first).each do |field|
          series = join_subfields(field, &subfield_not_in(%w{5 6 8 e t w v n}))
          pairs = field.map do |sf|
            if %w{e w v n t}.member?(sf.code)
              [ ' ', sf.value ]
            elsif sf.code == '4'
              [ ', ', relator_codes[sf.value] ]
            end
          end
          series_append = pairs.flatten.join.strip
          acc << { value: series, value_append: series_append, link_type: 'author_search' }
        end
      elsif %w{830 440 490}.member?(tags_present.first)
        rec.fields(tags_present.first).each do |field|
          series = join_subfields(field, &subfield_not_in(%w{5 6 8 c e w v n}))
          series_append = join_subfields(field, &subfield_in(%w{c e w v n}))
          acc << { value: series, value_append: series_append, link_type: 'title_search' }
        end
      end

      rec.fields(tags_present.drop(1)).each do |field|
        series = join_subfields(field, &subfield_not_in(%w{5 6 8}))
        acc << { value: series, link: false }
      end

      rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(800|810|811|830|400|410|411|440|490)/) }
          .each do |field|
        series = join_subfields(field, &subfield_in(%w{5 6 8}))
        acc << { value: series, link: false }
      end

      acc
    end

    def get_series_search_values(rec)
      acc = []
      acc += rec.fields(%w{400 410 411})
          .select { |f| f.indicator2 == '0' }
          .map do |field|
        join_subfields(field, &subfield_not_in(%w{4 6 8}))
      end
      acc += rec.fields(%w{400 410 411})
                 .select { |f| f.indicator2 == '1' }
                 .map do |field|
        join_subfields(field, &subfield_not_in(%w{4 6 8 a}))
      end
      acc += rec.fields(%w{440})
                 .map do |field|
        join_subfields(field, &subfield_not_in(%w{0 5 6 8 w}))
      end
      acc += rec.fields(%w{800 810 811})
                 .map do |field|
        join_subfields(field, &subfield_not_in(%w{0 4 5 6 7 8 w}))
      end
      acc += rec.fields(%w{830})
                 .map do |field|
        join_subfields(field, &subfield_not_in(%w{0 5 6 7 8 w}))
      end
      acc += rec.fields(%w{533})
                 .map do |field|
        field.find_all { |sf| sf.code == 'f' }
            .map(&:value)
            .map { |v| v.gsub(/\(|\)/, '') }
            .join(' ')
      end
      acc
    end

    def get_contained_within_values(rec)
      rec.fields('773').map do |field|
        results = field.find_all(&subfield_not_in(%w{6 8})).map(&:value)
        join_and_trim_whitespace(results)
      end
    end

    # @return [Array] of hashes each describing a physical holding
    def get_physical_holdings(rec)
      # enriched MARC looks like this:
      # <datafield tag="hld" ind1="0" ind2=" ">
      #   <subfield code="b">MAIN</subfield>
      #   <subfield code="c">main</subfield>
      #   <subfield code="h">NA2540</subfield>
      #   <subfield code="i">.G63 2009</subfield>
      #   <subfield code="8">226026380000541</subfield>
      # </datafield>
      rec.fields(EnrichedMarc::TAG_HOLDING).map do |item|
        # Alma never populates subfield 'a' which is 'location'
        # it appears to store the location code in 'c'
        # and display name in 'b'
        {
            holding_id: item[EnrichedMarc::SUB_HOLDING_SEQUENCE_NUMBER],
            location: item[EnrichedMarc::SUB_HOLDING_SHELVING_LOCATION],
            classification_part: item[EnrichedMarc::SUB_HOLDING_CLASSIFICATION_PART],
            item_part: item[EnrichedMarc::SUB_HOLDING_ITEM_PART],
        }
      end
    end

    # @return [Array] of hashes each describing an electronic holding
    def get_electronic_holdings(rec)
      # enriched MARC looks like this:
      # <datafield tag="prt" ind1=" " ind2=" ">
      #   <subfield code="pid">5310486800000521</subfield>
      #   <subfield code="url">https://sandbox01-na.alma.exlibrisgroup.com/view/uresolver/01UPENN_INST/openurl?u.ignore_date_coverage=true&amp;rft.mms_id=9926519600521</subfield>
      #   <subfield code="iface">PubMed Central</subfield>
      #   <subfield code="coverage"> Available from 2005 volume: 1. Most recent 1 year(s) not available.</subfield>
      #   <subfield code="library">MAIN</subfield>
      #   <subfield code="collection">PubMed Central (Training)</subfield>
      #   <subfield code="czcolid">61111058563444000</subfield>
      #   <subfield code="8">5310486800000521</subfield>
      # </datafield>

      # do NOT index electronic holdings where collection name is blank:
      # these are records created from 856 fields from Voyager
      # that don't have actual links.

      rec.fields(EnrichedMarc::TAG_ELECTRONIC_INVENTORY)
          .select { |item| item[EnrichedMarc::SUB_ELEC_COLLECTION_NAME].present? }
          .map do |item|
        {
            portfolio_pid: item[EnrichedMarc::SUB_ELEC_PORTFOLIO_PID],
            url: item[EnrichedMarc::SUB_ELEC_ACCESS_URL],
            collection: item[EnrichedMarc::SUB_ELEC_COLLECTION_NAME],
            coverage: item[EnrichedMarc::SUB_ELEC_COVERAGE],
        }
      end
    end

    def get_subfield_4ew(field)
      field.select(&subfield_in(%W{4 e w}))
          .map { |sf| (sf.code == '4' ? ", #{relator_codes[sf.value]}" : " #{sf.value}") }
          .join('')
    end

    def get_title_extra(field)
      join_subfields(field, &subfield_in(%W{e w}))
    end

    def get_other_title_display(rec)
      acc = []
      acc += rec.fields('246').map do |field|
        join_subfields(field, &subfield_not_in(%W{6 8}))
      end
      acc += rec.fields('740')
          .select { |f| ['', ' ', '0', '1', '3'].member?(f.indicator2) }
          .map do |field|
        join_subfields(field, &subfield_not_in(%W{5 6 8}))
      end
      acc += rec.fields('880')
          .select { |f| has_subfield6_value(f, /^(246|740)/) }
          .map do |field|
        join_subfields(field, &subfield_not_in(%W{5 6 8}))
      end
      acc
    end

    # distribution and manufacture share the same logic except for indicator2
    def get_264_or_880_fields(rec, indicator2)
      acc = []
      acc += rec.fields('264')
          .select { |f| f.indicator2 == indicator2 }
          .map do |field|
        join_subfields(field, &subfield_in(%w{a b c}))
      end
      acc += rec.fields('880')
          .select { |f| f.indicator2 == indicator2 }
          .select { |f| has_subfield6_value(f, /^264/) }
          .map do |field|
        join_subfields(field, &subfield_in(%w{a b c}))
      end
      acc
    end

    def get_distribution_display(rec)
      get_264_or_880_fields(rec, '2')
    end

    def get_manufacture_display(rec)
      get_264_or_880_fields(rec, '3')
    end

    def get_cartographic_display(rec)
      rec.fields(%w{255 342}).map do |field|
        join_subfields(field, &subfield_not_6_or_8)
      end
    end

    def get_fingerprint_display(rec)
      rec.fields('026').map do |field|
        join_subfields(field, &subfield_not_in(%w{2 5 6 8}))
      end
    end

    def get_arrangement_display(rec)
      get_datafield_and_880(rec, '351')
    end

    def get_former_title_display(rec)
      rec.fields
          .select { |f| f.tag == '247' || (f.tag == '880' && has_subfield6_value(f, /^247/)) }
          .map do |field|
        former_title = join_subfields(field, &subfield_not_in(%w{6 8 e w}))
        former_title_append = join_subfields(field, &subfield_in(%w{e w}))
        { value: former_title, value_append: former_title_append, link_type: 'title_search' }
      end
    end

    # logic for 'Continues' and 'Continued By' is very similar
    def get_continues(rec, tag)
      rec.fields
          .select { |f| f.tag == tag || (f.tag == '880' && has_subfield6_value(f, /^#{tag}/)) }
          .select { |f| f.any?(&subfield_in(%w{i a s t n d})) }
          .map do |field|
        join_subfields(field, &subfield_in(%w{i a s t n d}))
      end
    end

    def get_continues_display(rec)
      get_continues(rec, '780')
    end

    def get_continued_by_display(rec)
      get_continues(rec, '785')
    end

    def get_place_of_publication_display(rec)
      acc = []
      acc += rec.fields('752').map do |field|
        place = join_subfields(field, &subfield_not_in(%w{6 8 e w}))
        place_extra = join_subfields(field, &subfield_in(%w{e w}))
        { value: place, value_append: place_extra, link_type: 'search' }
      end
      acc += get_880_subfield_not_6_or_8(rec, '752').map do |result|
        { value: result, link: false }
      end
      acc
    end

    def get_language_display(rec)
      get_datafield_and_880(rec, '546')
    end

    # for system details: extract subfield 3 plus other subfields as specified by passed-in block
    def get_sub3_and_other_subs(field, &block)
      sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
      oth_subs = join_subfields(field, &block)
      [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
    end

    def get_system_details_display(rec)
      acc = []
      acc += rec.fields('538').map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a i u}))
      end
      acc += rec.fields('344').map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b c d e f g h}))
      end
      acc += rec.fields(%w{345 346}).map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b}))
      end
      acc += rec.fields('347').map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b c d e f}))
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^538/) }
                 .map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a i u}))
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^344/) }
                 .map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b c d e f g h}))
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^(345|346)/) }
                 .map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b}))
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^347/) }
                 .map do |field|
        get_sub3_and_other_subs(field, &subfield_in(%w{a b c d e f}))
      end
      acc
    end

    def get_biography_display(rec)
      get_datafield_and_880(rec, '545')
    end

    def get_summary_display(rec)
      get_datafield_and_880(rec, '520')
    end

    def get_contents_display(rec)
      acc = []
      acc += rec.fields('505').flat_map do |field|
        join_subfields(field, &subfield_not_6_or_8).split('--')
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^505/) }
                 .flat_map do |field|
        join_subfields(field, &subfield_not_6_or_8).split('--')
      end
      acc
    end

    def get_contents_note_search_values(rec)
      rec.fields('505').map do |field|
        join_and_trim_whitespace(field.to_a.map(&:value))
      end
    end

    def get_participant_display(rec)
      get_datafield_and_880(rec, '511')
    end

    def get_credits_display(rec)
      get_datafield_and_880(rec, '508')
    end

    def get_notes_display(rec)
      acc = []
      acc += rec.fields(%w{500 502 504 515 518 525 533 550 580 588}).map do |field|
        if field.tag == '588'
          join_subfields(field, &subfield_in(%w{a}))
        else
          join_subfields(field, &subfield_not_in(%w{5 6 8}))
        end
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^(500|502|504|515|518|525|533|550|580|588)/) }
                 .map do |field|
        sub6 = field.select(&subfield_in(%w{6})).map(&:value).first
        if sub6 == '588'
          join_subfields(field, &subfield_in(%w{a}))
        else
          join_subfields(field, &subfield_not_in(%w{5 6 8}))
        end
      end
      acc
    end

    def get_local_notes_display(rec)
      acc = []
      acc += rec.fields('590').map do |field|
        join_subfields(field, &subfield_not_in(%w{5 6 8}))
      end
      acc += get_880(rec, '590') do |sf|
        ! %w{5 6 8}.member?(sf.code)
      end
      acc
    end

    def get_finding_aid_display(rec)
      get_datafield_and_880(rec, '555')
    end

    # get 650/880 for provenance and chronology: prefix should be 'PRO' or 'CHR'
    def get_650_and_880(rec, prefix)
      acc = []
      acc += rec.fields('650')
                 .select { |f| f.indicator2 == '4' }
                 .select { |f| f.any? { |sf| sf.code == 'a' && sf.value =~ /^(#{prefix}|%#{prefix})/ } }
                 .map do |field|
        suba = field.select(&subfield_in(%w{a})).map {|sf|
          sf.value.gsub(/^%?#{prefix}/, '')
        }.join(' ')
        sub_others = join_subfields(field, &subfield_not_in(%w{a 6 8 e w}))
        value = [ suba, sub_others ].join(' ')
        { value: value, link_type: 'subject_search' } if value.present?
      end.compact
      acc += rec.fields('880')
                 .select { |f| f.indicator2 == '4' }
                 .select { |f| has_subfield6_value(f,/^650/) }
                 .select { |f| f.any? { |sf| sf.code == 'a' && sf.value =~ /^(#{prefix}|%#{prefix})/ } }
                 .map do |field|
        suba = field.select(&subfield_in(%w{a})).map {|sf| sf.value.gsub(/^%?#{prefix}/, '') }.join(' ')
        sub_others = join_subfields(field, &subfield_not_in(%w{a 6 8 e w}))
        value = [ suba, sub_others ].join(' ')
        { value: value, link_type: 'subject_search' } if value.present?
      end.compact
      acc
    end

    def get_provenance_display(rec)
      acc = []
      acc += rec.fields('561')
                 .select { |f| ['1', '', ' '].member?(f.indicator1) && [' ', ''].member?(f.indicator2) }
                 .map do |field|
        value = join_subfields(field, &subfield_in(%w{a}))
        { value: value, link: false } if value
      end.compact
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^561/) }
                 .select { |f| ['1', '', ' '].member?(f.indicator1) && [' ', ''].member?(f.indicator2) }
                 .map do |field|
        value = join_subfields(field, &subfield_in(%w{a}))
        { value: value, link: false } if value
      end.compact
      acc += get_650_and_880(rec, 'PRO')
      acc
    end

    def get_chronology_display(rec)
      get_650_and_880(rec, 'CHR')
    end

    def get_related_collections_display(rec)
      get_datafield_and_880(rec, '544')
    end

    def get_cited_in_display(rec)
      get_datafield_and_880(rec, '510')
    end

    def get_publications_about_display(rec)
      get_datafield_and_880(rec, '581')
    end

    def get_cite_as_display(rec)
      get_datafield_and_880(rec, '524')
    end

    def get_contributor_display(rec)
      acc = []
      acc += rec.fields(%w{700 710})
                 .select { |f| ['', ' ', '0'].member?(f.indicator2) }
                 .select { |f| f.none? { |sf| sf.code == 'i' } }
                 .map do |field|
        contributor = join_subfields(field, &subfield_in(%w{a b c d j q}))
        contributor_append = field.select(&subfield_in(%w{e u 3 4})).map do |sf|
          if sf.code == '4'
            ", #{relator_codes[sf.value]}"
          else
            " #{sf.value}"
          end
        end.join
        { value: contributor, value_append: contributor_append, link_type: 'author_creator_xfacet' }
      end
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^(700|710)/) && (f.none? { |sf| sf.code == 'i' }) }
                 .map do |field|
        contributor = join_subfields(field, &subfield_in(%w{a b c d j q}))
        contributor_append = join_subfields(field, &subfield_in(%w{e u 3}))
        { value: contributor, value_append: contributor_append, link_type: 'author_creator_xfacet' }
      end
      acc
    end

    # if there's a subfield i, extract its value, and if there's something
    # in parentheses in that value, extract that.
    def remove_paren_value_from_subfield_i(field)
      val = field.select { |sf| sf.code == 'i' }.map do |sf|
        if match = /\((.+?)\)/.match(sf.value)
          sf.value.sub('(' + match[1] + ')', '')
        else
          sf.value
        end
      end.first || ''
      trim_trailing_colon(trim_trailing_period(val))
    end

    def get_related_work_display(rec)
      acc = []
      acc += rec.fields(%w{700 710 711 730})
                 .select { |f| ['', ' '].member?(f.indicator2) }
                 .select { |f| f.any? { |sf| sf.code == 't' } }
                 .map do |field|
        subi = remove_paren_value_from_subfield_i(field) || ''
        related = field.map do |sf|
          if ! %w{0 4 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, related ].select(&:present?).join(':')
      end
      acc += rec.fields('880')
                 .select { |f| ['', ' '].member?(f.indicator2) }
                 .select { |f| has_subfield6_value(f, /^(700|710|711|730)/) }
                 .select { |f| f.any? { |sf| sf.code == 't' } }
                 .map do |field|
        subi = remove_paren_value_from_subfield_i(field) || ''
        related = field.map do |sf|
          if ! %w{0 4 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, related ].select(&:present?).join(':')
      end
      acc
    end

    def get_contains_display(rec)
      acc = []
      acc += rec.fields(%w{700 710 711 730 740})
                 .select { |f| f.indicator2 == '2' }
                 .map do |field|
        subi = remove_paren_value_from_subfield_i(field) || ''
        contains = field.map do |sf|
          if ! %w{0 4 5 6 8 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, contains ].select(&:present?).join(':')
      end
      acc += rec.fields('880')
                 .select { |f| f.indicator2 == '2' }
                 .select { |f| has_subfield6_value(f, /^(700|710|711|730|740)/) }
                 .map do |field|
        subi = remove_paren_value_from_subfield_i(field) || ''
        contains = join_subfields(field, &subfield_not_in(%w{0 5 6 8 i}))
        [ subi, contains ].select(&:present?).join(':')
      end
      acc
    end

    def get_other_edition_value(field)
      subi = remove_paren_value_from_subfield_i(field) || ''
      other_editions = field.map do |sf|
        if %w{s x z}.member?(sf.code)
          " #{sf.value}"
        elsif sf.code == 't'
          " #{relator_codes[sf.value]}. "
        end
      end.compact.join
      other_editions_append = field.map do |sf|
        if ! %w{i h s t x z e f o r w y 7}.member?(sf.code)
          " #{sf.value}"
        elsif sf.code == 'h'
          " (#{sf.value}) "
        end
      end.compact.join
      {
          value: other_editions,
          value_prepend: trim_trailing_period(subi) + ':',
          value_append: other_editions_append,
          link_type: 'author_creator_xfacet'
      }
    end

    def get_other_edition_display(rec)
      acc = []
      acc += rec.fields('775')
                 .select { |f| f.any? { |sf| sf.code == 'i' } }
                 .map do |field|
        get_other_edition_value(field)
      end
      acc += rec.fields('880')
                 .select { |f| ['', ' '].member?(f.indicator2) }
                 .select { |f| has_subfield6_value(f, /^775/) }
                 .select { |f| f.any? { |sf| sf.code == 'i' } }
                 .map do |field|
        get_other_edition_value(field)
      end
      acc
    end

    def get_contained_in_display(rec)
      acc = []
      acc += rec.fields('773').map do |field|
        join_subfields(field, &subfield_in(%w{a g i s t}))
      end.select(&:present?)
      acc += get_880(rec, '773') do |sf|
        %w{a g i s t}.member?(sf.code)
      end
      acc
    end

    def get_constituent_unit_display(rec)
      acc = []
      acc += rec.fields('774').map do |field|
        join_subfields(field, &subfield_in(%w{i a s t}))
      end.select(&:present?)
      acc += get_880(rec, '774') do |sf|
        %w{i a s t}.member?(sf.code)
      end
      acc
    end

    def get_has_supplement_display(rec)
      acc = []
      acc += rec.fields('770').map do |field|
        join_subfields(field, &subfield_not_6_or_8)
      end.select(&:present?)
      acc += get_880_subfield_not_6_or_8(rec, '770')
      acc
    end

    def get_other_format_display(rec)
      acc = []
      acc += rec.fields('776').map do |field|
        join_subfields(field, &subfield_in(%w{i a s t o}))
      end.select(&:present?)
      acc += get_880(rec, '774') do |sf|
        %w{i a s t o}.member?(sf.code)
      end
      acc
    end

    def get_isbn_display(rec)
      acc = []
      acc += rec.fields('020').map do |field|
        join_subfields(field, &subfield_in(%w{a z}))
      end.select(&:present?)
      acc += get_880(rec, '020') do |sf|
        %w{a z}.member?(sf.code)
      end
      acc
    end

    def get_issn_display(rec)
      acc = []
      acc += rec.fields('022').map do |field|
        join_subfields(field, &subfield_in(%w{a z}))
      end.select(&:present?)
      acc += get_880(rec, '022') do |sf|
        %w{a z}.member?(sf.code)
      end
      acc
    end

    def subfield_a_is_oclc(sf)
      sf.code == 'a' && sf.value =~ /^\(OCoLC\).*/
    end

    def get_oclc_id_values(rec)
      rec.fields('035')
          .select { |f| f.any? { |sf| subfield_a_is_oclc(sf) } }
          .take(1)
          .flat_map do |field|
        field.find_all { |sf| subfield_a_is_oclc(sf) }.map do |sf|
          m = /^\s*\(OCoLC\)[^1-9]*([1-9][0-9]*).*$/.match(sf.value)
          if m
            m[1]
          end
        end.compact
      end
    end

    def get_publisher_number_display(rec)
      acc = []
      acc += rec.fields(%w{024 028}).map do |field|
        join_subfields(field, &subfield_not_in(%w{5 6}))
      end.select(&:present?)
      acc += rec.fields('880')
                 .select { |f| has_subfield6_value(f, /^(024|028)/) }
                 .map do |field|
        join_subfields(field, &subfield_not_in(%w{5 6}))
      end
      acc
    end

    def get_access_restriction_display(rec)
      rec.fields('506').map do |field|
        join_subfields(field, &subfield_not_in(%w{5 6}))
      end.select(&:present?)
    end

    def get_bound_with_display(rec)
      rec.fields('501').map do |field|
        join_subfields(field, &subfield_not_in(%w{a}))
      end.select(&:present?)
    end

    # some logic to extract link text and link url from an 856 field
    def linktext_and_url(field)
      linktext_3 = join_subfields(field, &subfield_in(%w{3}))
      linktext_zy = field.find_all(&subfield_in(%w{z})).map(&:value).first ||
          field.find_all(&subfield_in(%w{y})).map(&:value).first || ''
      linktext = [ linktext_3, linktext_zy ].join(' ')
      linkurl = field.find_all(&subfield_in(%w{u})).map(&:value).first || ''
      linkurl = linkurl.sub(' target=_blank', '')
      [linktext, linkurl]
    end

    def get_online_display(rec)
      rec.fields('856')
          .select { |f| %w{0 1}.member?(f.indicator2) }
          .map do |field|
        linktext, linkurl = linktext_and_url(field)
        {
            linktext: linktext,
            linkurl: linkurl
        }
      end
    end

    def words_to_remove_from_web_link
      @words_to_remove_from_web_link ||=
          %w(fund funds collection collections endowment
          endowed trust and for of the memorial)
    end

    def get_web_link_display(rec)
      rec.fields('856')
          .select { |f| ['2', ' ', ''].member?(f.indicator2) }
          .flat_map do |field|
        links = []
        linktext, linkurl = linktext_and_url(field)
        links << {
            linktext: linktext,
            linkurl: linkurl
        }

        if linktext =~ /(Funds?|Collections?( +Gifts)?|Trust|Development) +Home +Page|A +Penn +Libraries +Collection +Gift/
          imagename = linktext.gsub(/- A Penn Libraries Collection Gift/i, '')
              .gsub(/ Home Page/i, '')
              .gsub(/[&.]/, '')
              .split(/\W+/)
              .select { |word| !words_to_remove_from_web_link.member?(word.downcase) }
              .join('')
          imagesource = "http://www.library.upenn.edu/images/alum/bookplates/#{imagename}.gif"
          links << {
              img_src: imagesource,
              img_alt: "#{linktext} Bookplate",
              linkurl: linkurl,
          }
        end

        links
      end
    end

    def get_call_number_search_values(rec)
      # not sure whether it's better to use 'item' or 'holding' records here.
      # we use 'item' only because it has a helpful call number type subfield,
      # which the holding doesn't.
      rec.fields(EnrichedMarc::TAG_ITEM).map do |item|
        cn_type = item.find_all { |sf| sf.code == EnrichedMarc::SUB_ITEM_CALL_NUMBER_TYPE }.map(&:value).first

        item.find_all { |sf| sf.code == EnrichedMarc::SUB_ITEM_CALL_NUMBER }
                      .map(&:value)
                      .select { |call_num| call_num.present? }
                      .map { |call_num| call_num }
                      .compact
      end.flatten(1)
    end

    def get_call_number_xfacet_values(rec)
      get_call_number_search_values(rec).map do |v|
        references(v)
      end
    end

    def get_recently_added_sort_values(rec)
      # TODO: we're not able to find or get a "date record was added to Alma"
      # which is what we want here. so we use 005 for now, but that date reflects updates.
      # Note that 008 has the date that the MARC record was created,
      # but that's not useful here.
      acc = rec.fields('005')
                .select { |f| f.value.present? && !f.value.start_with?('0000') }
                .map do |field|
        begin
          DateTime.iso8601(field.value).to_i
        rescue ArgumentError => e
          nil
        end
      end.compact
      # records without a date should be considered very old
      if acc.size == 0
        acc += [0]
      end
      acc
    end

    def get_full_text_link_values(rec)
      rec.fields('856')
          .select { |f| (f.indicator1 == '4') && %w{0 1}.member?(f.indicator2) }
          .map do |field|
        linktext, linkurl = linktext_and_url(field)
        %Q{<a href="#{linkurl}">#{linktext.present? ? linktext : linkurl}</a>}
      end
    end

    # It's not clear whether Alma can suppress these auto-generated
    # records (Primo instances seem to show these records!) so we filter
    # them out here just in case
    def is_boundwith_record(rec)
      rec.fields('245').any? { |f|
        title = join_subfields(f, &subfield_in(%w{a}))
        title.include?('Host bibliographic record for boundwith')
      }
    end

    # values for passed-in args come from Solr, not extracted directly from MARC.
    # TODO: this code should return more data-ish values; the HTML should be moved into a render method
    def get_offsite_display(rec, crl_id, title, author, oclc_id)
      id = crl_id
      html = %Q{<a href="#{"http://catalog.crl.edu/record=#{id}~S1"}">Center for Research Libraries Holdings</a>}

      f260  = rec.fields('260')
      place = f260.map { |f| join_subfields(f, &subfield_in(%w{a})) }.join(' ')
      publisher = f260.map { |f| join_subfields(f, &subfield_in(%w{b})) }.join(' ')
      pubdate = f260.map { |f| join_subfields(f, &subfield_in(%w{c})) }.join(' ')

      atlas_params = {
          crl_id: id,
          title: title,
          author: author,
          oclc: oclc_id,
          place: place,
          publisher: publisher,
          pubdate: pubdate,
      }
      atlas_url = "https://atlas.library.upenn.edu/cgi-bin/forms/illcrl.cgi?#{atlas_params.to_query}"

      html += %Q{<a href="#{atlas_url}">Place request</a>}

      f590  = rec.fields('590')
      if f590.size > 0
        html += '<div>'
        f590.each do |field|
          html += field.join(' ')
        end
        html += '</div>'
      end
      [ html ]
    end

  end

end
