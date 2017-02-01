
require 'nokogiri'

module PennLib

  # Class for doing extraction and processing on MARC::Record objects
  #
  # This is intended to be used in both indexing code and front-end templating code
  # (since MARC is stored in Solr). As such, there should NOT be any traject-specific
  # things here.
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

    def trim_trailing_colon(s)
      s.sub(/:$/, '')
    end

    def trim_trailing_semicolon(s)
      s.sub(/;$/, '')
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
      s.sub(/\s*\.\s*$/, '')
    end

    def normalize_space(s)
      s.strip.gsub(/\s{2,}/, ' ')
    end

    def join_and_trim_whitespace(array)
      normalize_space(array.join(' '))
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
    # @param block [Proc] takes a subfield as argument, returns a boolean
    def get_880(rec, subf6_value, &block)
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^#{subf6_value}/ } }
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
        field.select(&subfield_not_in(%w{6 8})).map(&:value).join(' ')
      end
      acc += get_880_subfield_not_6_or_8(rec, tag)
      acc
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

    def is_subject_field(field)
      ['600', '610', '611', '630', '650', '651'].member?(field.tag) && ['0','2','4'].member?(field.indicator2)
    end

    # if double_dash is true, then some subfields are joined together with --
    def join_subject_parts(field, double_dash: false)
      parts = field.find_all(&subfield_in(['a'])).map(&:value)
      parts += field.find_all(&subfield_not_in(%w{a 6 5})).map do |sf|
        (double_dash && !%w{b c d q t}.member?(sf.code) ? ' -- ' : ' ') + sf.value
      end
      parts.join(' ')
    end

    def get_subject_facet_values(rec)
      rec.fields.find_all { |f| is_subject_field(f) }.map do |f|
        join_subject_parts(f)
      end
    end

    def get_subject_xfacet_values(rec)
      subjects = rec.fields.find_all { |f| is_subject_field(f) }.map do |f|
        join_subject_parts(f, double_dash: true)
      end
      subjects.map { |s| references(s, refs: get_subject_references(s)) }
    end

    def get_format
      # TODO: there's some complex logic for determining the format of a record,
      # depending on location, 008, and other things
    end

    def get_format_display(rec)
      results = []
      results += rec.fields('300').map do |field|
        field.select(&subfield_not_in(%w{3 6 8})).map(&:value).join(' ')
      end
      results += rec.fields(%w{254 255 310 342 352 362}).map do |field|
        field.select(&subfield_not_in(%w{6 8})).map(&:value).join(' ')
      end
      results += rec.fields(%w{340}).map do |field|
        field.select(&subfield_not_in(%w{0 2 6 8})).map(&:value).join(' ')
      end
      results += rec.fields(%w{880}).map do |field|
        if field.any? { |sf| sf.code == '6' && sf.value =~ /^300/ }
          field.select(&subfield_not_in(%w{3 6 8})).map(&:value).join(' ')
        elsif field.any? { |sf| sf.code == '6' && sf.value =~ /^(254|255|310|342|352|362)/ }
          field.select(&subfield_not_in(%w{6 8})).map(&:value).join(' ')
        elsif field.any? { |sf| sf.code == '6' && sf.value =~ /^340/ }
          field.select(&subfield_not_in(%w{0 2 6 8})).map(&:value).join(' ')
        else
          []
        end
      end
      results
    end

    def get_access_values(rec)
      acc = []
      # CRL records are 'Offsite'
      rec.each do |f|
        case f.tag
          when 'hld'
            acc << 'At the library'
          when 'prt'
            acc << 'Online'
        end
      end
      acc
    end

    # examines a 1xx datafield and constructs a string out of select
    # subfields, including expansion of 'relator' code
    def get_name_1xx_field(field)
      s = ''
      field.each do |sf|
        if(! %W{4 6 8}.member?(sf.code))
          s << " #{sf.value}"
        end
        if sf.code == '4'
          s << ", #{relator_codes[sf.value]}"
        end
      end
      if !['.', '-'].member?(s[-1])
        s << '.'
      end
      normalize_space(s)
    end

    def get_series_8xx_field(field)
      s = ''
      field.each do |sf|
        if(! %W{4 5 6 8}.member?(sf.code))
          s << " #{sf.value}"
        end
        if sf.code == '4'
          s << ", #{relator_codes[sf.value]}"
        end
      end
      if !['.', '-'].member?(s[-1])
        s << '.'
      end
      normalize_space(s)
    end

    def get_series_4xx_field(field)
      s = ''
      field.each do |sf|
        if(! %W{4 6 8}.member?(sf.code))
          s << " #{sf.value}"
        end
        if sf.code == '4'
          s << ", #{relator_codes[sf.value]}"
        end
      end
      if !['.', '-'].member?(s[-1])
        s << '.'
      end
      normalize_space(s)
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
        publication = field.find_all(&subfield_not_6_or_8).map(&:value).join(' ')
        acc << publication
      end
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(260|261|262)/ } }
          .take(1)
          .each do |field|
        publication = field.find_all(&subfield_not_6_or_8).map(&:value).join(' ')
        acc << publication
      end
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^245/ } }
          .each do |field|
        publication = field.find_all(&subfield_in(['f'])).map(&:value).join(' ')
        acc << publication
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

    def get_library_values(rec)
      acc = []
      rec.fields('hld').each do |field|
        # TODO: might be a, b, or c, it's hard to tell. need to verify against final data.
        field.find_all { |sf| sf.code == 'a' }
            .map { |sf| locations[sf.value] || "Van Pelt (TODO)" }
            .each { |library| acc << library }
      end
      acc
    end

    def get_specific_location_values(rec)
      acc = []
      rec.fields('hld').each do |field|
        # TODO: might be a, b, or c, it's hard to tell. need to verify against final data.
        field.find_all { |sf| sf.code == 'c' }
            .map { |sf| locations[sf.value] || "1st Floor (TODO)" }
            .each { |loc| acc << loc }
      end
      acc
    end

    def get_publication_date_values(rec)
      rec.fields('008').map { |field| field.value[7,4] }
          .select { |year| year.present? }
          .map { |year| year.gsub(/\D/, '0') }
          .select { |year| year =~ /^[1-9][0-9]/ && current_year + 15 > year.to_i }
          .map { |year| year[0, 3] + '0s' }
    end

    def get_classification_values(rec)
      acc = []
      # TODO: Alma has "Call number", "Alternative call number" and "Temporary call number" subfields;
      # use 'hld' instead?
      rec.fields('itm').each do |item|
        cn_type = item.find_all { |sf| sf.code == 'cntype' }.map { |sf| cn_type = sf.value }.first

        results = item.find_all { |sf| sf.code == 'cnf' }
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
      acc
    end

    def get_genre_values(rec)
      acc = []

      # TODO: not sure this check is totally right
      is_manuscript = rec.fields('itm').any? do |item|
        item['cloc'] =~ /manuscript/
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

    def get_genre_display(rec, should_link)
      rec.fields
          .select { |f| f.tag == '655' || (f.tag == '880' && f.any? { |sf| sf.code == '6' && sf.value =~ /655/ }) }
          .map do |field|
        sub_with_hyphens = field.find_all(&subfield_not_in(%w{0 2 5 6 8 c e w})).map do |sf|
          sep = ! %w{a b }.member?(sf.code) ? ' -- ' : ' '
          sep + sf.value
        end.join
        eandw_with_hyphens = field.find_all(&subfield_in(%w{e w})).join(' -- ')
        { value: sub_with_hyphens, value_append: eandw_with_hyphens, link: should_link, link_type: 'genre_search' }
      end
    end

    def get_title_search_values(rec)
      acc = []
      rec.fields(%w{245 880}).each do |field|
        acc.concat(field.find_all(&subfield_not_in(%w{c 6 8 h})).map(&:value))
      end
      acc
    end

    def get_author_values(rec)
      rec.fields(%w{100 110}).map do |field|
        get_name_1xx_field(field)
      end
    end

    def get_title_values(rec)
      acc = []
      rec.fields('245').take(1).each do |field|
        a_or_k = field.find_all(&subfield_in(%w{a k}))
                     .map { |sf| trim_trailing_comma(trim_trailing_slash(sf.value).rstrip) }
                     .first
        joined = field.find_all(&subfield_in(%w{b n p}))
                     .map{ |sf| trim_trailing_slash(sf.value) }
                     .join(' ')

        apunct = a_or_k[-1]
        hpunct = field.find_all { |sf| sf.code == 'h' }
                     .map{ |sf| sf.value[-1] }
                     .first
        punct = if [apunct, hpunct].member?('=') then
                  '='
                else
                  [apunct, hpunct].member?(':') ? ':' : nil
                end

        acc << [ trim_trailing_colon(trim_trailing_equal(a_or_k)), punct, joined ].compact.join(' ')
      end
      acc
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
        title = field.select(&subfield_not_in(%W{6 8 e w})).map(&:value).join(' ')
        title_param_value = field.select(&subfield_not_in(%W{5 6 8 e w})).map(&:value).join(' ')
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
        title = field.select(&subfield_not_in(%w{5 6 8 e w})).map(&:value).join(' ')
        title_append = get_title_extra(field)
        acc << {
            value: title,
            value_append: title_append,
            link_type: 'title_search' }
      end
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(130|240|730)/ } }
          .select { |f| f.none? { |sf| sf.code == 'i'} }
          .each do |field|
        title = field.select(&subfield_not_in(%w{5 6 8 e w})).map(&:value).join(' ')
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
      rec.fields('250').each do |field|
        acc << field.find_all(&subfield_not_in(%W{6 8})).map(&:value).join(' ')
      end
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^250/ } }
          .each do |field|
        acc << field.find_all(&subfield_not_in(%W{6 8})).map(&:value).join(' ')
      end
      acc
    end

    def get_conference_values(rec)
      rec.fields('111').map do |field|
        get_name_1xx_field(field)
      end
    end

    def get_conference_display(rec)
      results = rec.fields(%w{111 711})
          .select{ |f| ['', ' '].member?(f.indicator2) }
          .map do |field|
        conf = ''
        if field.none? { |sf| sf.code == 'i' }
          conf = field.find_all(&subfield_not_in(%w{4 5 6 8 e j w})).map(&:value).join(' ')
        end
        conf_append = field.find_all(&subfield_in(%w{e j w})).map(&:value).join(', ')
        { value: conf, value_append: conf_append, link_type: 'author_xfacet' }
      end
      results += rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(111|711)/ } }
          .select { |f| f.none? { |sf| sf.code == 'i' } }
          .map do |field|
        conf = field.find_all(&subfield_not_in(%w{4 5 6 8 e j w})).map(&:value).join(' ')
        conf_extra = field.find_all(&subfield_in(%w{4 e j w})).map(&:value).join(', ')
        { value: conf, value_append: conf_extra, link_type: 'author_xfacet' }
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

    def get_series_display(rec)
      acc = []

      series_tags = %w{800 810 811 830 400 411 440 490}.select { |tag| rec[tag].present? }

      if %w{800 810 811 400 410 411}.member?(series_tags.first)
        rec.fields(series_tags.first).each do |field|
          series = field.select(&subfield_not_in(%w{5 6 8 e t w v n})).map(&:value).join(' ')
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
      elsif %w{830 440 490}.member?(series_tags.first)
        rec.fields(series_tags.first).each do |field|
          series = field.select(&subfield_not_in(%w{5 6 8 c e w v n})).map(&:value).join(' ')
          series_append = field.select(&subfield_in(%w{c e w v n})).map(&:value).join(' ')
          acc << { value: series, value_append: series_append, link_type: 'title_search' }
        end
      end

      rec.fields(series_tags.drop(1)).each do |field|
        series = field.select(&subfield_not_in(%w{5 6 8})).map(&:value).join(' ')
        acc << { value: series, link: false }
      end

      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(800|810|811|830|400|410|411|440|490)/ } }
          .each do |field|
        series = field.select(&subfield_in(%w{5 6 8})).map(&:value).join(' ')
        acc << { value: series, link: false }
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
      physical_holdings = []
      rec.fields('hld').each do |item|
        # these are MARC 852 subfield codes
        physical_holdings << {
            holding_id: item['8'],
            location: item['a'],
            shelving_location: item['c'],
            classification_part: item['h'],
            item_part: item['i'],
        }
      end
      physical_holdings
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
      electronic_holdings = []
      rec.fields('prt').each do |item|
        electronic_holdings << {
            portfolio_pid: item['pid'],
            url: item['url'],
            collection: item['collection'],
            coverage: item['coverage'],
        }
      end
      electronic_holdings
    end

    def get_subfield_4ew(field)
      field.select(&subfield_in(%W{4 e w}))
          .map { |sf| (sf.code == '4' ? ', ' : ' ') + "#{relator_codes[sf.value]}" }
          .join('')
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
            link_type: 'author_xfacet' }
      end
      rec.fields('880').each do |field|
        if field.any? { |sf| sf.code == '6' && sf.value =~ /^(100|110)/ }
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
              link_type: 'author_xfacet' }
        end
      end
      acc
    end

    def get_title_extra(field)
      field.select(&subfield_in(%W{e w})).map(&:value).join(' ')
    end

    def get_other_title_display(rec)
      acc = []
      rec.fields('246').each do |field|
        other_title = field.select(&subfield_not_in(%W{6 8})).map(&:value).join(' ')
        acc << other_title
      end
      rec.fields('740')
          .select { |f| ['', ' ', '0', '1', '3'].member?(f.indicator2) }
          .each do |field|
        other_title = field.select(&subfield_not_in(%W{5 6 8})).map(&:value).join(' ')
        acc << other_title
      end
      rec.fields('880')
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(246|740)/ } }
          .each do |field|
        other_title = field.select(&subfield_not_in(%W{5 6 8})).map(&:value).join(' ')
        acc << other_title
      end
      acc
    end

    # distribution and manufacture share the same logic except for indicator2
    def get_264_or_880_fields(rec, indicator2)
      acc = []
      rec.fields('264')
          .select { |f| f.indicator2 == indicator2 }
          .each do |field|
        acc << field.select(&subfield_in(%w{a b c})).map(&:value).join(' ')
      end
      rec.fields('880')
          .select { |f| f.indicator2 == indicator2 }
          .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^264/ } }
          .each do |field|
        acc << field.select(&subfield_in(%w{a b c})).map(&:value).join(' ')
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
        field.select(&subfield_not_6_or_8).map(&:value).join(' ')
      end
    end

    def get_fingerprint_display(rec)
      rec.fields('026').map do |field|
        field.select(&subfield_not_in(%w{2 5 6 8})).map(&:value).join(' ')
      end
    end

    def get_arrangement_display(rec)
      get_datafield_and_880(rec, '351')
    end

    def get_former_title_display(rec)
      acc = []
      acc += rec.fields
                 .select { |f| f.tag == '247' || (f.tag == '880' && f.any? { |sf| sf.code == '6' && sf.value =~ /^247/}) }
                 .map do |field|
        former_title = field.select(&subfield_not_in(%w{6 8 e w})).map(&:value).join(' ')
        former_title_append = field.select(&subfield_in(%w{e w})).map(&:value).join(' ')
        { value: former_title, value_append: former_title_append, link_type: 'title_search' }
      end
      acc
    end

    # logic for 'Continues' and 'Continued By' is very similar
    def get_continues(rec, tag)
      acc = []
      acc += rec.fields
                 .select { |f| f.tag == tag || (f.tag == '880' && f.any? { |sf| sf.code == '6' && sf.value =~ /^#{tag}/}) }
                 .select { |f| f.any?(&subfield_in(%w{i a s t n d})) }
                 .map do |field|
        field.select(&subfield_in(%w{i a s t n d})).map(&:value).join(' ')
      end
      acc
    end

    def get_continues_display(rec)
      get_continues(rec, '780')
    end

    def get_continued_by_display(rec)
      get_continues(rec, '785')
    end

    # @returns [Array] of string field tags to examine for subjects
    def subject_600s
      %w{600 610 611 630 650 651}
    end

    def get_subjects_from_600s_and_800(rec, indicator2)
      acc = []
      if %w{0 1 2}.member?(indicator2)
        # Subjects, Childrens subjects, and Medical Subjects all share this code
        acc += rec.fields
                   .select { |f| subject_600s.member?(f.tag) ||
                      (f.tag == '800' && f.any? { |sf| sf.code == '6' && sf.value =~ /^(#{subject_600s.join('|')})/ }) }
                   .select { |f| f.indicator2 == indicator2 }
                   .map do |field|
          value_for_link = field.select(&subfield_not_in(%w{6 8 2 e w})).map(&:value).join(' ')
          sub_with_hyphens = field.select(&subfield_not_in(%w{6 8 2 e w})).map do |sf|
            pre = !%w{a b c d p q t}.member?(sf.code) ? ' -- ' : ' '
            pre + sf.value + (sf.code == 'p' ? '.' : '')
          end.join(' ')
          eandw_with_hyphens = field.select(&subfield_in(%w{e w})).map do |sf|
            ' -- ' + sf.value
          end.join(' ')
          {
              value: sub_with_hyphens,
              value_for_link: value_for_link,
              value_append: eandw_with_hyphens,
              link_type: 'subject_xfacet'
          }
        end
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
          sub_oth_no_hyphens = field.select(&subfield_not_in(%w{a 6 8})).map(&:value).join(' ')
          subj_search = [ suba, sub_oth_no_hyphens ].join(' ')
          {
              value: subj_display,
              value_for_link: subj_search,
              link_type: 'search'
          }
        end
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

    def get_place_of_publication_display(rec)
      acc = []
      acc += rec.fields('752').map do |field|
        place = field.select(&subfield_not_in(%w{6 8 e w})).map(&:value).join(' ')
        place_extra = field.select(&subfield_in(%w{e w})).map(&:value).join(' ')
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

    def get_system_details_display(rec)
      # TODO: refactor for better DRY
      acc = []
      acc += rec.fields('538').map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a i u})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields('344').map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b c d e f g h})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{345 346}).map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{347}).map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b c d e f})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^538/ } }
                 .map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a i u})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^344/ } }
                 .map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b c d e f g h})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(345|346)/ } }
                 .map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
      end
      acc += rec.fields(%w{880})
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^347/ } }
                 .map do |field|
        sub3 = field.select(&subfield_in(%w{3})).map(&:value).map { |v| trim_trailing_period(v) }.join(': ')
        oth_subs = field.select(&subfield_in(%w{a b c d e f})).map(&:value).join(' ')
        [ sub3, trim_trailing_semicolon(oth_subs) ].join(' ')
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
        joined = field.select(&subfield_not_6_or_8).map(&:value).join(' ')
        joined.split('--')
      end
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^505/ } }
                 .flat_map do |field|
        joined = field.select(&subfield_not_6_or_8).map(&:value).join(' ')
        joined.split('--')
      end
      acc
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
          field.select(&subfield_in(%w{a})).map(&:value).join(' ')
        else
          field.select(&subfield_not_in(%w{5 6 8})).map(&:value).join(' ')
        end
      end
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(500|502|504|515|518|525|533|550|580|588)/ } }
                 .map do |field|
        sub6 = field.select(&subfield_in(%w{6})).map(&:value).first
        if sub6 == '588'
          field.select(&subfield_in(%w{a})).map(&:value).join(' ')
        else
          field.select(&subfield_not_in(%w{5 6 8})).map(&:value).join(' ')
        end
      end
      acc
    end

    def get_local_notes_display(rec)
      acc = []
      acc += rec.fields(%w{590}).map do |field|
        field.select(&subfield_not_in(%w{5 6 8})).map(&:value).join(' ')
      end
      acc += get_880(rec, '590') do |sf|
        ! %w{5 6 8}.member?(sf.code)
      end
      acc
    end

    def get_finding_aid_display(rec)
      get_datafield_and_880(rec, '555')
    end

    # get 650/880 for provenance and chronology: value should be 'PRO' or 'CHR'
    def get_650_and_880(rec, value)
      acc = []
      acc += rec.fields('650')
                 .select { |f| f.indicator2 == '4' }
                 .map do |field|
        suba = field.select(&subfield_in(%w{a})).select { |sf| sf.value =~ /^(#{value}|%#{value})/ }
                   .map {|sf| sf.value.gsub(/^%?#{value}/, '') }.join(' ')
        sub_others = field.select(&subfield_not_in(%w{a 6 8 e w})).map(&:value).join(' ')
        value = [ suba, sub_others ].join(' ')
        { value: value, link_type: 'subject_search' } if value.present?
      end.compact
      acc += rec.fields('880')
                 .select { |f| f.indicator2 == '4' }
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^650/ }  }
                 .map do |field|
        suba = field.select(&subfield_in(%w{a})).select { |sf| sf.value =~ /^(#{value}|%#{value})/ }
                   .map {|sf| sf.value.gsub(/^%?#{value}/, '') }.join(' ')
        sub_others = field.select(&subfield_not_in(%w{a 6 8 e w})).map(&:value).join(' ')
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
        value = field.select(&subfield_in(%w{a})).map(&:value).join(' ')
        { value: value, link: false } if value
      end.compact
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^561/ } }
                 .select { |f| ['1', '', ' '].member?(f.indicator1) && [' ', ''].member?(f.indicator2) }
                 .map do |field|
        value = field.select(&subfield_in(%w{a})).map(&:value).join(' ')
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
        contributor = field.select(&subfield_in(%w{a b c d j q})).map(&:value).join(' ')
        contributor_append = field.select(&subfield_in(%w{e u 3 4})).map do |sf|
          if sf.code == '4'
            ", #{relator_codes[sf.value]}"
          else
            " #{sf.value}"
          end
        end.join
        { value: contributor, value_append: contributor_append, link_type: 'author_xfacet' }
      end
      acc += rec.fields('880')
                 .select { |f| (f.any? { |sf| sf.code == '6' && sf.value =~ /^(700|710)/ }) && (f.none? { |sf| sf.code == 'i' }) }
                 .map do |field|
        contributor = field.select(&subfield_in(%w{a b c d j q})).map(&:value).join(' ')
        contributor_append = field.select(&subfield_in(%w{e u 3})).map(&:value).join(' ')
        { value: contributor, value_append: contributor_append, link_type: 'author_xfacet' }
      end
      acc
    end

    # if there's a subfield i, extract its value, and if there's something
    # in parentheses in that value, extract that.
    def get_subfield_i_value_from_parens(field)
      val = field.select { |sf| sf.code == 'i' }.map do |sf|
        if match = /\((.+)\)/.match(sf.value)
          match[1]
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
        subi = get_subfield_i_value_from_parens(field) || ''
        related = field.map do |sf|
          if ! %w{0 4 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, related ].select(&:present?).join(' ')
      end
      acc += rec.fields('880')
                 .select { |f| ['', ' '].member?(f.indicator2) }
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(700|710|711|730)/ } }
                 .select { |f| f.any? { |sf| sf.code == 't' } }
                 .map do |field|
        subi = get_subfield_i_value_from_parens(field) || ''
        related = field.map do |sf|
          if ! %w{0 4 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, related ].select(&:present?).join(' ')
      end
      acc
    end

    def get_contains_display(rec)
      acc = []
      acc += rec.fields(%w{700 710 711 730 740})
                 .select { |f| f.indicator2 == '2' }
                 .map do |field|
        subi = get_subfield_i_value_from_parens(field) || ''
        contains = field.map do |sf|
          if ! %w{0 4 5 6 8 i}.member?(sf.code)
            " #{sf.value}"
          elsif sf.code == '4'
            ", #{relator_codes[sf.value]}"
          end
        end.compact.join
        [ subi, contains ].select(&:present?).join(' ')
      end
      acc += rec.fields('880')
                 .select { |f| f.indicator2 == '2' }
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(700|710|711|730|740)/ } }
                 .map do |field|
        subi = get_subfield_i_value_from_parens(field) || ''
        contains = field.map(&subfield_not_in(%w{0 5 6 8 i})).map(&:value).join(' ')
        [ subi, contains ].select(&:present?).join(' ')
      end
      acc
    end

    def get_other_edition_value(field)
      subi = get_subfield_i_value_from_parens(field) || ''
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
          value_prepend: trim_trailing_period(subi),
          value_append: other_editions_append,
          link_type: 'author_xfacet'
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
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^775/ } }
                 .select { |f| f.any? { |sf| sf.code == 'i' } }
                 .map do |field|
        get_other_edition_value(field)
      end
      acc
    end

    def get_contained_in_display(rec)
      acc = []
      acc += rec.fields('773').map do |field|
        field.select(&subfield_in(%w{a g i s t})).map(&:value).join(' ')
      end.select(&:present?)
      acc += get_880(rec, '773') do |sf|
        %w{a g i s t}.member?(sf.code)
      end
      acc
    end

    def get_constituent_unit_display(rec)
      acc = []
      acc += rec.fields('774').map do |field|
        field.select(&subfield_in(%w{i a s t})).map(&:value).join(' ')
      end.select(&:present?)
      acc += get_880(rec, '774') do |sf|
        %w{i a s t}.member?(sf.code)
      end
      acc
    end

    def get_has_supplement_display(rec)
      acc = []
      acc += rec.fields('770').map do |field|
        field.select(&subfield_not_6_or_8).map(&:value).join(' ')
      end.select(&:present?)
      acc += get_880_subfield_not_6_or_8(rec, '770')
      acc
    end

    def get_other_format_display(rec)
      acc = []
      acc += rec.fields('776').map do |field|
        field.select(&subfield_in(%w{i a s t o})).map(&:value).join(' ')
      end.select(&:present?)
      acc += get_880(rec, '774') do |sf|
        %w{i a s t o}.member?(sf.code)
      end
      acc
    end

    def get_isbn_display(rec)
      acc = []
      acc += rec.fields('020').map do |field|
        field.select(&subfield_in(%w{a z})).map(&:value).join(' ')
      end.select(&:present?)
      acc += get_880(rec, '020') do |sf|
        %w{a z}.member?(sf.code)
      end
      acc
    end

    def get_issn_display(rec)
      acc = []
      acc += rec.fields('022').map do |field|
        field.select(&subfield_in(%w{a z})).map(&:value).join(' ')
      end.select(&:present?).select(&:present?)
      acc += get_880(rec, '022') do |sf|
        %w{a z}.member?(sf.code)
      end
      acc
    end

    def get_oclc_display(rec)
      # TODO: how to get OCLC? from holdings?
      []
    end

    def get_publisher_number_display(rec)
      acc = []
      acc += rec.fields(%w{024 028}).map do |field|
        field.select(&subfield_not_in(%w{5 6})).map(&:value).join(' ')
      end.select(&:present?)
      acc += rec.fields('880')
                 .select { |f| f.any? { |sf| sf.code == '6' && sf.value =~ /^(024|028)/ } }
                 .map do |field|
        field.select(&subfield_not_in(%w{5 6})).map(&:value).join(' ')
      end
      acc
    end

    def get_access_restriction_display(rec)
      rec.fields(%w{506}).map do |field|
        field.select(&subfield_not_in(%w{5 6})).map(&:value).join(' ')
      end.select(&:present?)
    end

    def get_bound_with_display(rec)
      rec.fields(%w{501}).map do |field|
        field.select(&subfield_not_in(%w{a})).map(&:value).join(' ')
      end.select(&:present?)
    end

  end

end
