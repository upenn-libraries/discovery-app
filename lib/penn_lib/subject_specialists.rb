module PennLib
  # methods to facilitate retrieval of subject specialist data from PennLib
  # Drupal site
  module SubjectSpecialists
    DRUPAL_SPECIALISTS_URL =
      'https://www.library.upenn.edu/rest/views/subject-specialists?_format=json'.freeze
    CACHE_KEY = :subject_specialist_data

    class << self
      # Returns specialist info hash, and sets the cached value if needed,
      # returning nil if neither the cached date nor the live data passes
      # the seems_legit? test
      # @return [Hash, nil]
      def data
        cached_data = Rails.cache.read CACHE_KEY
        return cached_data if seems_legit? cached_data

        cache_data
      end

      # Set specialist data in cache if it passes the seems_legit? test
      # If it fails, return nil. THe display helper should then render the view
      # that doesn't require the specialist info
      # @return [Hash, nil]
      def cache_data
        data = subjects
        return nil unless seems_legit? data

        Rails.cache.write CACHE_KEY, data, expires_in: 24.hours
        data
      end

      # Roughly determine if data is a valid subject_specialists data
      # structure. This ain't pretty but it is what it is.
      # @param [Hash] data
      # @return [TrueClass, FalseClass]
      def seems_legit?(data)
        # ensure we aren't dealing with a blank value
        return false if data.blank?

        # ensure first array element is also an array
        return false unless data.first.is_a? Array

        # ensure the second element of the first array element is also an
        # array
        return false unless data.first.second&.is_a? Array

        # ensure the place where we expect the actual hash of data has one of
        # the keys we expect
        return false unless data.first.second.first&.key? 'subject_specialty'

        true
      end

      # return hash of subjects for use in display of subject specialist info
      # @return [Hash]
      def subjects
        specialists = ActiveSupport::HashWithIndifferentAccess.new
        subjects = ActiveSupport::HashWithIndifferentAccess.new
        live_specialists_data = retrieve_specialist_json
        return unless live_specialists_data

        live_specialists_data.each do |specialty|
          # nasty way to make the subject hash key match Drupal anchor tag ids
          subject_key = specialty['subject_specialty'].gsub(/[&#;]/, '')
                                                      .parameterize.underscore
          specialty = specialty.transform_values { |v| CGI.unescapeHTML v }
          name = specialty['full_name'].parameterize.underscore
          subjects[subject_key] = [] unless subjects[subject_key]
          subjects[subject_key] << name
          if specialists[name]
            specialists[name][:subjects] << specialty['subject_specialty']
          else
            specialty[:subjects] = [specialty['subject_specialty']]
            specialty[:display_name] = specialty['full_name']
            specialty[:portrait] =
              "https://www.library.upenn.edu#{specialty['thumbnail']}"
            specialists[name] = specialty
          end
        end
        subjects.each do |subject, staff|
          subjects[subject] = staff.map { |name| specialists[name] }
        end
      end

      # Pull and parse data from Drupal endpoint
      # Will retry up to 2 times and return nil if there are issues parsing JSON
      # @return [Hash, NilClass]
      def retrieve_specialist_json
        connection = Faraday.new do |conn|
          conn.request :retry, max: 2, interval: 0.1, backoff_factor: 2
          conn.adapter :net_http
        end
        response_body = connection.get(DRUPAL_SPECIALISTS_URL).body
        JSON.parse(response_body)
      # handle attempt to parse nil or empty response, as well as connection
      # errors
      rescue TypeError, JSON::JSONError, Faraday::ClientError => _e
        nil
      end
    end
QUERIES = {
    # the only purpose served by this top-level of hierarchy is to group the nested facet
    # queries, where the real "work" happens. This allows them to be easily parsed, disabled,
    # etc. as a group.
    type: 'query',
    domain: {query: '{!query v=$correlation_domain}'},
    q: '{!query v=$correlation_domain}', # specify here as well as in domain; fgSet only respects fcontext.parent.filter!
    facet: {
  accounting: {
    type: 'query',
    # this domain (and some others) are implicitly focused on more recent content. The
    # post_1928 filter is a somewhat arbitrary date restriction to narrow the focus of
    # these domains; $post_1928 query is defined in catalog controller, default solr params
    q: '{!bool filter=\'{!term f=subject_search v=accounting}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  africana_studies: {
    # "africana" is a general term that is more likely to appear in the record at large
    # than in an official "subject" field, so we inspect the catch-all marcrecord_xml field
    type: 'query',
    q: '{!term f=marcrecord_xml v=africana}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  african_studies: {
    type: 'query',
    q: '{!term f=subject_search v=africa}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  anthropology: {
    type: 'query',
    q: '{!term f=subject_search v=anthropology}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  archaeology: {
    type: 'query',
    q: '{!term f=subject_search v=archaeology}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  architectural_history: {
    type: 'query',
    # prefix searches on subject_f are good for capturing a heading and all associated subheadings
    q: '{!prefix f=subject_f v=Architecture--History}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  architecture_amp_city_planning: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=architecture}\' filter=\'{!term f=subject_search v=planning}\' filter=\'{!term f=subject_search v=city}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  art_amp_art_history: {
    type: 'query',
    q: '{!prefix f=subject_f v=Art--History}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  asian_american_studies: {
    type: 'query',
    # "double quoted" search yields a phrase search
    q: '{!field f=subject_search v=\'"asian american"\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  bioethics: {
    type: 'query',
    q: '{!term f=subject_search v=bioethics}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  bioinformatics: {
    type: 'query',
    q: '{!term f=subject_search v=bioinformatics}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  biology: {
    type: 'query',
    # see comment about $post_1928 under entry for "accounting"
    q: '{!bool filter=\'{!term f=subject_search v=biology}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  biomedical_graduate_studies: {
    type: 'query',
    q: '{!term f=subject_search v=biomedical}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  biomedical_research: {
    type: 'query',
    q: '{!term f=subject_search v=biomedical}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  business_economics_amp_public_policy: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=business}\' filter=\'{!term f=subject_search v=public}\' filter=\'{!term f=subject_search v=policy}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  chemistry: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=chemistry}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  chinese_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=china,chinese}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  cinema_amp_media_studies: {
    type: 'query',
    q: '{!bool should=\'{!complexphrase df=subject_search v=\\\'"motion (picture pictures)"\\\'}\' should=\'{!terms f=subject_search v=media,cinema}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  classical_studies: {
    type: 'query',
    q: '{!bool should=\'{!prefix f=subject_f v=Classical}\' should=\'{!term f=language_f v=Latin}\' should=\'{!term f=language_f v=\\\'Greek, Ancient (to 1453)\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  communication: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=communication}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  comparative_literature: {
    type: 'query',
    q: '{!prefix f=subject_f v=\'Comparative literature\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  criminology: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=criminology}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  dental_medicine: {
    type: 'query',
    q: '{!bool filter=\'{!prefix f=subject_f v=Dentistry}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  earth_amp_environmental_science: {
    type: 'query',
    q: '{!bool should=\'{!prefix f=subject_f v=\\\'Earth sciences\\\'}\' should=\'{!prefix f=subject_f v=\\\'Environmental sciences\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  economics: {
    type: 'query',
    q: '{!term f=subject_search v=economics}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  education: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=education}\' must_not=\'{!term f=subject_f v=\\\'Health education\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  engineering_amp_computer_science: {
    type: 'query',
    q: '{!bool should=\'{!term f=subject_search v=engineering}\' should=\'{!prefix f=subject_f v=\\\'Computer \\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  entrepreneurship: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=entrepreneurship}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  finance: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=finance}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  fine_arts: {
    type: 'query',
    q: '{!prefix f=subject_f v=Art--}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  folklore_amp_folklife: {
    type: 'query',
    q: '{!bool should=\'{!prefix f=subject_f v=Folklore}\' should=\'{!prefix f=subject_f v=Ethnology}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  french_language_amp_literature: {
    type: 'query',
    # match on "filter" clause means that no "should" clauses need to match; so we have to bundle the
    # "should" clauses together as a top-level "filter" clause
    q: '{!bool filter=\'{!term f=subject_search v=french}\' filter=\'{!bool should=\\\'{!term f=subject_search v=language}\\\' should=\\\'{!term f=subject_search v=literature}\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  gender_sexuality_amp_women039s_studies: {
    type: 'query',
    q: '{!bool should=\'{!term f=subject_search v=gender}\' should=\'{!term f=subject_search v=sexuality}\' should=\'{!prefix f=subject_f v=\\\'Women\\\\\\\'s studies\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  general_science: {
    type: 'query',
    q: '{!bool filter=\'{!prefix f=subject_f v=Science}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  geographic_information_systems: {
    type: 'query',
    q: '{!prefix f=subject_f v=\'Geographic information systems\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  germanic_languages_amp_literatures: {
    type: 'query',
    # see comment on mixed "filter" and "should" clauses under "french...", above
    q: '{!bool filter=\'{!prefix f=subject_search v=german}\' filter=\'{!bool should=\\\'{!prefix f=subject_search v=language}\\\' should=\\\'{!term f=subject_search v=literature}\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  health_care_management: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=health}\' filter=\'{!term f=subject_search v=care}\' filter=\'{!terms f=subject_search v=management,economics}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  historic_preservation: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=historic}\' filter=\'{!bool should=\\\'{!term f=subject_search v=preservation}\\\' should=\\\'{!term f=subject_search v=conservation}\\\' should=\\\'{!term f=subject_search v=restoration}\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  history: {
    type: 'query',
    q: '{!term f=subject_search v=history}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  history_amp_sociology_of_science: {
    type: 'query',
    # loose/"sloppy" proximity search is the most efficient way to catch the relevant subjects here, so we use edismax
    # "political" caused a bunch of spurious matches, so we blacklist it
    q: '{!bool should=\'{!edismax qf=subject_search pf=subject_search v=\\\'"sociology science"~5\\\'}\' should=\'{!edismax qf=subject_search pf=subject_search v=\\\'"history science"~5\\\'}\' must_not=\'{!term f=subject_search v=political}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  humanities_general: {
    type: 'query',
    # this is a huge domain, by design. But correlation will account for that and should
    # only match this domain for very broad queries
    q: '{!terms f=subject_search v=anthropology,archaeology,classical,history,linguistics,language,law,politics,literature,philosophy,religion,art}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  international_business: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=international}\' filter=\'{!term f=subject_search=business}\' filter=$post_1928}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  international_relations: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=international}\' filter=\'{!term f=subject_search=relations}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  italian_language_amp_literature: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=italian}\' filter=\'{!bool should=\\\'{!term f=subject_search v=language}\\\' should=\\\'{!term f=subject_search v=literature}\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  japanese_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=japan,japanese}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  judaica_special_collections: {
    type: 'query',
    q: '{!bool filter=\'{!term f=library_f v=\\\'Special Collections\\\'}\' filter=\'{!terms f=subject_search v=judaism,jews,jewish}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  judaic_studies: {
    type: 'query',
    # $culture_filter covers various markers pertaining to culture. It is general enough to be reused elsewhere
    # (e.g., perhaps for the "language & literature" domains, though for now these are defined specifically wrt
    # "language" and "literature"
    # NOTE: better results were achieved with the more targeted "Jewish" prefix search than were achieved via
    # simply including "jewish" in the "terms" query.
    q: '{!bool filter=\'{!bool should=\\\'{!terms f=subject_search v=judaism,jews}\\\' should=\\\'{!prefix f=subject_f v=Jewish}\\\'}\' filter=$culture_filter}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  korean_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=korea,korean}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  landscape_architecture: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=landscape}\' filter=\'{!term f=subject_search v=architecture}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  latin_american_studies: {
    type: 'query',
    q: '{!prefix f=subject_f v=\'Latin America\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  latino_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=hispanic,latino}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  legal_studies_amp_business_ethics: {
    type: 'query',
    q: '{!bool should=\'{!terms f=subject_search v=legal,law,laws}\' should=\'{!bool filter=\\\'{!term f=subject_search v=business}\\\' filter=\\\'{!term f=subject_search v=ethics}\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  linguistics: {
    type: 'query',
    q: '{!term f=subject_search v=linguistics}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  literature_in_english: {
    type: 'query',
    q: '{!bool filter=\'{!bool should=\\\'{!term f=language_f v=English}\\\' should=\\\'{!term f=subject_search v=english}\\\'}\' filter=\'{!term f=subject_search v=literature}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  management: {
    type: 'query',
    # opted *not* to explicitly filter to $post_1928 here; unlike for "accounting" and "biology",
    # this term should effectively self-select to more modern materials without extra filtering
    q: '{!term f=subject_search v=management}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  manuscript_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=manuscript,manuscripts}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  marketing: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=marketing}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  mathematics: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=mathematics}\' filter=$post_1928}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  medicine: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=medicine}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  medieval_manuscripts: {
    type: 'query',
    # somewhat arbitrary date range delimiting "medieval" from "modern" mss.
    # per fraas, early renaissance mss are usually bundled with medieval, hence
    # the magic 1600 date
    q: '{!bool filter=\'{!bool should=\\\'{!term f=subject_search v=medieval}\\\' should=\\\'content_min_dtsort:[* TO 1600-01-01T00:00:00Z]\\\'}\' filter=\'{!terms f=subject_search v=manuscript,manuscripts}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  medieval_studies: {
    type: 'query',
    # see note above ("medieval manuscripts") wrt somewhat-arbitrary date range filter
    q: '{!bool should=\'{!term f=subject_search v=medieval}\' should=\'content_min_dtsort:[* TO 1600-01-01T00:00:00Z]\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  middle_eastern_studies: {
    type: 'query',
    q: '{!prefix f=subject_f v=\'Middle East\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  modern_manuscripts_amp_archives: {
    type: 'query',
    # see note above (under "medieval_manuscripts") re: arbitrary dividing line between "medieval+" and "modern" 
    q: '{!bool filter=\'{!bool should=\\\'{!term f=format_f v=Archive}\\\' should=\\\'{!terms f=subject_search v=manuscript,manuscripts}\\\'}\' filter=\'content_max_dtsort:[1601-01-01T00:00:00Z TO *]\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  music: {
    type: 'query',
    q: '{!bool should=\'{!term f=subject_search v=music}\' should=\'{!terms f=format_f v=\\\'Sound recording,Musical score\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  nonprofit_leadership: {
    type: 'query',
    q: '{!prefix f=subject_f v=Nonprofit}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  nursing: {
    type: 'query',
    q: '{!term f=subject_search v=nursing}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  operations_information_amp_decisions: {
    type: 'query',
    q: '{!bool should=\'{!prefix f=subject_f v=\\\'Operations research\\\'}\' should=\'{!prefix f=subject_f v=\\\'Decision making\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  organizational_dynamics: {
    type: 'query',
    q: '{!prefix f=subject_f v=Organizational}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  philosophy: {
    type: 'query',
    q: '{!term f=subject_search v=philosophy}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  philosophy_politics_amp_economics: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=philosophy}\' filter=\'{!terms f=subject_search v=politics,political,economic,economics}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  physics_amp_astronomy: {
    type: 'query',
    q: '{!bool should=\'{!terms f=subject_search v=physics,astronomy}\' should=\'{!prefix f=subject_f v=Astrophysic}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  political_science: {
    type: 'query',
    q: '{!prefix f=subject_f v=\'Political science\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  political_science_data: {
    type: 'query',
    q: '{!bool filter=\'{!prefix f=subject_search v=politic}\' filter=\'{!term f=subject_search v=data}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  psychology: {
    type: 'query',
    q: '{!term f=subject_search v=phsychology}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  rare_books_amp_printed_materials: {
    type: 'query',
    # per fraas, location-based domain should be ok. This will not be perfect for all cases, but
    # "perfect for all cases" is not an attainable goal ...
    q: '{!bool should=\'{!bool filter=\\\'{!term f=library_f v=\\\\\\\'Special Collections\\\\\\\'}\\\' must_not=\\\'{!term f=format_f v=Manuscript}\\\'}\' should=\'{!prefix f=subject_f v=\\\'Rare books\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  real_estate: {
    type: 'query',
    q: '{!bool filter=\'{!complexphrase df=subject_search v=\\\'"real (estate property)"\\\'}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  regional_science: {
    type: 'query',
    q: '{!complexphrase df=subject_search v=\'"(political economic human commercial physical historical urban cultural) geography"\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  religious_studies: {
    type: 'query',
    q: '{!terms f=subject_search v=religion,religious}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  russian_amp_east_european_studies: {
    type: 'query',
    q: '{!bool should=\'{!terms f=subject_search v=russia,soviet,slavic,yugoslavia,bosnia,croatia,serbia,ukraine,poland,hungary,czech,belarus}\' should=\'{!terms f=lanuage_f v=Ukranian,Russian,Bosnian,Croatian,Serbian,Belarusian,Hungarian,Czech,Polish}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
#  scholarly_publishing: {
#    type: 'query',
#    q: '{!bool filter=\'{!term f=subject_search v=scholarly}\' filter=\'{!term f=subject_search v=publishing}\'}',
#    facet: {
#      r1: 'relatedness($combo,$back)'
#    }
#  },
  social_impact: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=social}\' filter=\'{!terms f=subject_search v=economic,political,business,policy}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  social_policy: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=social}\' filter=\'{!terms f=subject_search v=economic,political,business}\' filter=\'{!term f=subject_f v=policy}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  social_science_data: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=social}\' filter=\'{!terms f=subject_search v=science,sciences}\' filter=\'{!terms f=subject_search v=data,methods,methodology,statistical,statistics}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  social_work: {
    type: 'query',
    q: '{!complexphrase df=subject_search v=\'"social (work service)"~1\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  sociology: {
    type: 'query',
    q: '{!term f=subject_search v=sociology}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  south_asian_studies: {
    type: 'query',
    q: '{!bool should=\'{!complexphrase df=subject_search v=\\\'"south (asia asian)"\\\'}\' should=\'{!terms f=subject_search v=afghanistan,bangladesh,bhutan,india,maldives,nepal,pakistan}\' should=\'{!field f=subject_search v=\\\'"sri lanka"\\\'}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  southeast_asian_studies: {
    type: 'query',
    q: '{!bool should=\'{!complexphrase df=subject_search v=\\\'"southeast (asia asian)"\\\'}\' should=\'{!terms f=subject_search v=cambodia,laos,myanmar,malaysia,thailand,vietnam,indonesia,philippines,singapore}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  spanish_portuguese_amp_iberian_studies: {
    type: 'query',
    q: '{!bool should=\'{!terms f=subject_search v=spanish,spain,portuguese,portugal}\' should=\'{!terms f=lanuage_f v=Spanish,Portuguese}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  statistics: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=statistics}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  theatre_arts: {
    type: 'query',
    q: '{!term f=subject_search v=theater}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  urban_studies: {
    type: 'query',
    q: '{!bool filter=\'{!prefix f=subject_f v=\\\'City planning\\\'}\' filter=\'{!term f=subject_search v=urban}\'}',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  },
  veterinary_medicine: {
    type: 'query',
    q: '{!bool filter=\'{!term f=subject_search v=veterinary}\' filter=$post_1928 }',
    facet: {
      r1: 'relatedness($combo,$back)'
    }
  }
  }
}.freeze
  end
end
