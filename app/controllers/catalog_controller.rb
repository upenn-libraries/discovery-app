
require 'uri'

# frozen_string_literal: true
class CatalogController < ApplicationController
  include ReplaceInvalidBytes
  include BlacklightAdvancedSearch::Controller
  include Blacklight::Catalog
  include Blacklight::Marc::Catalog
  include Blacklight::Ris::Catalog
  include BlacklightSolrplugins::XBrowse
  include HandleInvalidAdvancedSearch
  include AssociateExpandedDocs
  include HandleEmptyEmail

  ENABLE_SUBJECT_CORRELATION = true #ENV['ENABLE_SUBJECT_CORRELATION']&.downcase == 'true'

  # expire session if needed
  before_action :expire_session

  # screen for illegit sort params
  before_action :block_invalid_sort_params, only: :index

  # establish an effective "record depth" beyond which pagination is not supported
  PAGINATION_THRESHOLD = 1000
  before_action :limit_index_pagination, only: :index
  before_action :limit_show_pagination, only: :show

  # and also for facets
  FACET_PAGINATION_THRESHOLD = 50
  before_action :limit_facet_pagination, only: :facet

  SECONDS_PER_DAY = 86_400

  configure_blacklight do |config|
    # default advanced config values
    config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # config.advanced_search[:qt] ||= 'advanced'
    config.advanced_search[:url_key] ||= 'advanced'
    config.advanced_search[:query_parser] ||= 'perEndPosition_dense_shingle_graphSpans'
    config.advanced_search[:form_solr_parameters] ||= {}


    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    config.response_model = BlacklightSolrplugins::Response

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
        #cache: 'false',
        defType: 'perEndPosition_dense_shingle_graphSpans',
        combo: '{!filters param=$q param=$fq excludeTags=cluster,no_correlation}', # NOTE: $correlation_domain is applied within facets
        presentation_domain: '{!filters param=$q param=$fq}', # default, overridden for first-class subject_correlation search_field
        post_1928: 'content_max_dtsort:[1929-01-01T00:00:00Z TO *]',
        culture_filter: "{!bool should='{!terms f=subject_search v=literature,customs,religion,ethics,society,social,culture,cultural}' should='{!prefix f=subject_search v=art}'}",
        #combo: '{!bool must=$q filter=\'{!filters param=$fq v=*:*}\'}',
        #combo: '{!query v=$q}',
        # this list is annoying to maintain, but this avoids hard-coding a field list
        # in the search request handler in solrconfig.xml
        fl: %w{
        id
        cluster_id
        alma_mms_id
        score
        format_a
        full_text_link_a
        isbn_isxn
        language_a
        title
        title_880_a
        author_creator_a
        author_880_a
        standardized_title_a
        edition
        conference_a
        series
        publication_a
        contained_within_a
        physical_holdings_json
        electronic_holdings_json
        bound_with_ids_a
        marcrecord_text
        recently_added_isort
        hld_count_isort
        prt_count_isort
      }.join(','),
        'facet.threads': 2,
        'facet.mincount': 0,
        # this approach needs expand.field=cluster_id
        cluster: '{!tieredDomainDedupe f=record_source_f joinField=cluster_id v=Penn,Brown,Chicago,Columbia,Cornell,Duke,Harvard,Princeton,Stanford,HathiTrust}',
        back: '{!query v=$correlation_domain}',
        # NOTE: correlation_domain is separately defined from correlation_domain_refine so that the latter may be applied
        # and selectively excluded (via excludeTags) for reporting counts over the full cluster domain, while calculating
        # relatedness over a subset of that domain. This is not always necessary -- e.g., in the case where counts are not
        # needed, such as for "expert help", which can use correlation_domain directly
        correlation_domain: '{!bool filter=$cluster filter=$correlation_domain_refine}',
        correlation_domain_refine: '{!bool filter=elvl_rank_isort:0}',
        expand: 'true',
        'expand.field': 'cluster_id',
        'expand.q': '*:*',
        'expand.fq': '*:*',
        rows: 10
    }

    # solr path which will be added to solr base url before the other solr params.
    #config.solr_path = 'select'

    # items to show per page, each number in the array represent another option to choose from.
    config.per_page = [25, 50, 100]

    ## Default parameters to send on single-document requests to Solr. These settings are the Blackligt defaults (see SearchHelper#solr_doc_params) or
    ## parameters included in the Blacklight-jetty document requestHandler.
    config.default_document_solr_params = {
        expand: 'true',
        'expand.field': 'cluster_id',
        'expand.q': '*:*',
    }

    # solr field configuration for search results/index views
    config.index.title_field = 'title'
    # config.index.display_type_field = 'format'
    config.index.document_presenter_class = PennLib::IndexPresenter

    # our custom ShowPresenter: we use this to override the heading
    config.show.document_presenter_class = PennLib::ShowPresenter

    # solr field configuration for document/show views
    #config.show.title_field = 'title_display'
    config.show.display_type_field = 'format_a'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to create the navigation (note: It is case sensitive when searching values)

    database_selected = lambda { |a, b, c|
      a.params.dig(:f, :format_f)&.include?('Database & Article Index')
    }

    local_only = lambda { |a, b, c|
      'Include Partner Libraries' != a.params.dig(:f, :cluster, 0)
    }

    # Some filters (e.g., subject_f) are capable of driving meaningful correlations;
    # others are not, and either generate spurious correlations, or at best pointlessly add extra
    # overhead to Solr request.
    # Keys below indicate filters that we should not attempt to use for purpose of cacluating
    # correlations -- either entirely (nil value) or for an array of certain filter values
    # TODO: in search_builder, tag corresponding fq's with `no_correlation` so that they may be
    # excluded from calculation of foreground domains for the purpose of relatedness/correlation
    # calculation.
    CORRELATION_IGNORELIST = {
      :access_f => nil,
      :record_source_f => nil,
      :cluster => nil,
      :format_f => ['Database & Article Index']
    }.freeze

    params_actionable_filters = lambda { |params|
      return true if params[:q].present?
      f = params[:f]
      return false if f.nil?
      # we return true if there is at least one non-ignorelisted filter
      return true if f.size > CORRELATION_IGNORELIST.size
      f.symbolize_keys.each do |facet_key, facet_values|
        return true unless CORRELATION_IGNORELIST.include?(facet_key) # no vals are ignored for this key
        ignorelisted_vals = CORRELATION_IGNORELIST[facet_key]
        next unless ignorelisted_vals # all vals are ignored for this key
        return true if (facet_values - ignorelisted_vals).present? # there is at least one non-ignored val
      end
      return false
    }

    actionable_filters = lambda { |a, b, c|
      params_actionable_filters.call(a.params)
    }

    conditional_sort_options = lambda { |params|
      if params_actionable_filters.call(params)
        ['index', 'count', 'r1 desc']
      else
        ['index', 'count']
      end
    }

    search_field_accept = lambda { |field_names, other_conditions = []|
      return lambda { |a, b, c|
        return false unless field_names.include?(a.params[:search_field])
        other_conditions.each do |condition|
          return false unless condition.call(a, b, c)
        end
        return true
      }
    }

    search_field_reject = lambda { |field_names, other_conditions = []|
      return lambda { |a, b, c|
        return false if field_names.include?(a.params[:search_field])
        other_conditions.each do |condition|
          return false unless condition.call(a, b, c)
        end
        return true
      }
    }

    config.induce_sort = lambda { |blacklight_params|
      return 'title_nssort asc' if blacklight_params.dig(:f, :format_f)&.include?('Database & Article Index')
    }

    config.facet_types = {
        :first_class => {
            :priority => 3,
            :sidebar => false,
            :display => 'First class filters'
        },
        :header => {
            :priority => 2,
            :sidebar => false,
            :display => 'Header filters'
        },
        :default => {
            :priority => 1,
            :display => 'General filters'
        },
        :database => {
            :priority => 0,
            :display => 'Database filters'
        }
    }

    DATABASE_CATEGORY_TAXONOMY = {
      db_category_f: {
        type: 'terms',
        field: 'db_category_f',
        mincount: 1,
        limit: -1,
        sort: 'index',
        facet: {
          db_subcategory_f: {
            type: 'terms',
            prefix: '$parent--',
            field: 'db_subcategory_f',
            mincount: 1,
            limit: -1,
            sort: 'index'
          }
        }
      }
    }.freeze

    SUBJECT_TAXONOMY = {
      subject_taxonomy: {
        type: 'terms',
        field: 'toplevel_subject_f',
        top_level_term: 'term()',
        facet: {
          identity: {
            type: 'query',
            q: '{!term f=subject_f v=$top_level_term}',
          },
          subject_f: {
            type: 'terms',
            prefix: '$top_level_term--',
            field: 'subject_f',
            limit: 5
          }
        }
      }
    }.freeze

    MINCOUNT = { 'facet.mincount' => 1 }.freeze

    CORRELATION_JSON_FACET = lambda { |field, limit, offset, sort, prefix|
      overRequestRatio = 0.7 # default is 0.1
      overRefineRatio = 24 # often based on number of shards
      if field == 'subject_f'
        overrequest = (limit * overRequestRatio).to_i + 4 # based on the default forumula
        ## overrefine = ((offset + limit) * 0.1).to_i + 4 # the default
        # essentially, we want to refine *everything* that comes back from the
        # initial requests, because we're dealing with high-cardinality and
        # correspondingly low-frequency/unevently distributed fields/values.
        overrefine = ((offset + limit + overrequest) * overRefineRatio).to_i + 4
      else
        overrequest = -1
        overrefine = -1
      end
      return nil unless ENABLE_SUBJECT_CORRELATION && sort == 'r1 desc'
      {
        type: 'query',
        domain: {
          query: '{!query ex=cluster v=$cluster}'
        },
        q: '{!query tag=REFINE v=$correlation_domain}',
        blacklight_options: {
          parse: {
            delegate: lambda { |subs| subs[:correlation] }
          }
        },
        facet: {
          correlation:{
            type: 'terms',
            field: field,
            # NOTE: mincount pre-filters vals that could not possibly match min_pop
            mincount: 2, # guarantee fgSize >= 2
            limit: limit,
            offset: offset,
            overrequest: overrequest,
            overrefine: overrefine,
            refine: 'simple',
            cacheDf: -1, # disable caching; only affects refinement. esp. important b/c of extent of overrefining
            sort: sort,
            blacklight_options: {
              parse: {
                filter: lambda { |bucket| bucket[:r1][:relatedness] > 0 },
                get_hits: lambda { |bucket| bucket[:fg_filtered_count][:count] }
              }
            },
            facet: {
              processEmpty: true,
              r1: {
                type: 'func',
                min_popularity: 0.0000002, # lower bound n/bgSize to guarantee fgCount>=n (here, n==2)
                func: 'relatedness($combo,$back)'
              },
              fg_all_count: { # count over unfiltered logical base domain
                domain: {
                  excludeTags: 'REFINE'
                },
                type: 'query',
                q: '*:*'
              },
              fg_filtered_count: { # count over logical base domain, filtered by q and fq
                domain: {
                  excludeTags: 'REFINE',
                  filter: '{!query v=$presentation_domain}',
                },
                type: 'query',
                q: '*:*'
              }
            }
          }
        }
      }
    }.freeze

    NO_FACET_SEARCH_FIELDS = ['subject_correlation'].freeze

    config.add_facet_field 'cluster', label: 'Search domain', collapse: false, single: :manual, solr_params: MINCOUNT, query: {
        #'Penn' => { :label => 'Penn', :fq => '{!term tag=cluster ex=cluster f=record_source_f v=Penn}'},
        'Include Partner Libraries' => { :label => 'Include Partner Libraries', :fq => '{!query tag=cluster ex=cluster v=$cluster}'}
    }
    config.add_facet_field 'db_subcategory_f', label: 'Database Subject', if: lambda { |a,b,c| false }
    config.add_facet_field 'db_category_f', label: 'Database Subject', collapse: false, :partial => 'blacklight/hierarchy/facet_hierarchy',
                           :json_facet => DATABASE_CATEGORY_TAXONOMY, :sub_hierarchy => [:db_subcategory_f], :facet_type => :database,
                           :helper_method => :render_subcategories, :if => database_selected

    config.add_facet_field 'db_type_f', label: 'Database Type', limit: -1, collapse: false,
                           :if => database_selected,
                           :facet_type => :database, solr_params: MINCOUNT
    # NOTE: set facet_type=nil below, to bypass normal facet display
    config.add_facet_field 'subject_specialists', label: 'Subject Area Correlation', collapse: true, :facet_type => nil,
        :json_facet => PennLib::JsonFacet::Config.new(PennLib::SubjectSpecialists::QUERIES), :if => actionable_filters

    config.add_facet_field 'subject_f',
                           label: 'Subject',
                           collapse: false,
                           limit: 5,
                           index_range: 'A'..'Z',
                           solr_params: MINCOUNT,
                           sort_options: conditional_sort_options,
                           sort: 'r1 desc', # 'r1 desc', 'count', or 'index'
                           #partial: 'catalog/json_facet_limit',
                           json_facet: PennLib::JsonFacet::Config.new(CORRELATION_JSON_FACET, {
                             if: actionable_filters,
                             fallback: {
                               map_sort: lambda { |sort, blacklight_params| sort == 'r1 desc' ? 'count' : sort }
                             }
                           }),
                           facet_type: lambda { |params|
                             params[:search_field] == 'subject_correlation' ? :first_class : :default
                           }

    config.add_facet_field 'author_creator_f',
                           label: 'Author/Creator',
                           collapse: false,
                           limit: 5,
                           index_range: 'A'..'Z',
                           solr_params: MINCOUNT,
                           sort_options: conditional_sort_options,
                           sort: 'r1 desc', # 'r1 desc', 'count', or 'index'
                           #partial: 'catalog/json_facet_limit',
                           json_facet: PennLib::JsonFacet::Config.new(CORRELATION_JSON_FACET, {
                             if: actionable_filters,
                             fallback: {
                               map_sort: lambda { |sort, blacklight_params| sort == 'r1 desc' ? 'count' : sort }
                             }
                           }),
                           facet_type: lambda { |params|
                             params[:search_field] == 'author_creator_correlation' ? :first_class : :default
                           }

    config.add_facet_field 'azlist', label: 'A-Z List', collapse: false, single: :manual, :facet_type => :header,
                           options: {:layout => 'horizontal_facet_list'}, solr_params: { 'facet.mincount' => 0 },
                           :if => database_selected, query: {
            'A' => { :label => 'A', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='a'}"},
            'B' => { :label => 'B', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='b'}"},
            'C' => { :label => 'C', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='c'}"},
            'D' => { :label => 'D', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='d'}"},
            'E' => { :label => 'E', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='e'}"},
            'F' => { :label => 'F', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='f'}"},
            'G' => { :label => 'G', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='g'}"},
            'H' => { :label => 'H', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='h'}"},
            'I' => { :label => 'I', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='i'}"},
            'J' => { :label => 'J', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='j'}"},
            'K' => { :label => 'K', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='k'}"},
            'L' => { :label => 'L', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='l'}"},
            'M' => { :label => 'M', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='m'}"},
            'N' => { :label => 'N', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='n'}"},
            'O' => { :label => 'O', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='o'}"},
            'P' => { :label => 'P', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='p'}"},
            'Q' => { :label => 'Q', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='q'}"},
            'R' => { :label => 'R', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='r'}"},
            'S' => { :label => 'S', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='s'}"},
            'T' => { :label => 'T', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='t'}"},
            'U' => { :label => 'U', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='u'}"},
            'V' => { :label => 'V', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='v'}"},
            'W' => { :label => 'W', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='w'}"},
            'X' => { :label => 'X', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='x'}"},
            'Y' => { :label => 'Y', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='y'}"},
            'Z' => { :label => 'Z', :fq => "{!prefix tag=azlist ex=azlist f=title_xfacet v='z'}"},
            'Other' => { :label => 'Other', :fq => "{!tag=azlist ex=azlist}title_xfacet:/[ -`{-~].*/"}
        }
    config.add_facet_field 'access_f', label: 'Access', collapse: false, solr_params: MINCOUNT, :if => local_only, query: {
        'Online' => { :label => 'Online', :fq => "{!join ex=orig_q from=cluster_id to=cluster_id v='access_f:Online OR record_source_id:3'}"},
        'At the library' => { :label => 'At the library', :fq => "{!join ex=orig_q from=cluster_id to=cluster_id v='{!term f=access_f v=\\'At the library\\'}'}"},
    }
    config.add_facet_field 'format_f', label: 'Format', limit: 5, collapse: false, :ex => 'orig_q', solr_params: MINCOUNT, :if => local_only, query: {
        'Book' => { :label => 'Book', :fq => "{!term f=format_f v='Book'}"},
        'Government document' => { :label => 'Government document', :fq => "{!term f=format_f v='Government document'}"},
        'Journal/Periodical' => { :label => 'Journal/Periodical', :fq => "{!term f=format_f v='Journal/Periodical'}"},
        'Microformat' => { :label => 'Microformat', :fq => "{!term f=format_f v='Microformat'}"},
        'Sound recording' => { :label => 'Sound recording', :fq => "{!term f=format_f v='Sound recording'}"},
        'Musical score' => { :label => 'Musical score', :fq => "{!term f=format_f v='Musical score'}"},
        'Video' => { :label => 'Video', :fq => "{!term f=format_f v='Video'}"},
        'Conference/Event' => { :label => 'Conference/Event', :fq => "{!term f=format_f v='Conference/Event'}"},
        'Manuscript' => { :label => 'Manuscript', :fq => "{!term f=format_f v='Manuscript'}"},
        'Thesis/Dissertation' => { :label => 'Thesis/Dissertation', :fq => "{!term f=format_f v='Thesis/Dissertation'}"},
        'Newspaper' => { :label => 'Newspaper', :fq => "{!term f=format_f v='Newspaper'}"},
        'Datafile' => { :label => 'Datafile', :fq => "{!term f=format_f v='Datafile'}"},
        'Image' => { :label => 'Image', :fq => "{!term f=format_f v='Image'}"},
        'Website/Database' => { :label => 'Website/Database', :fq => "{!term f=format_f v='Website/Database'}"},
        'Map/Atlas' => { :label => 'Map/Atlas', :fq => "{!term f=format_f v='Map/Atlas'}"},
        'Archive' => { :label => 'Archive', :fq => "{!term f=format_f v='Archive'}"},
        'Other' => { :label => 'Other', :fq => "{!term f=format_f v='Other'}"},
        'Database & Article Index' => { :label => 'Database & Article Index', :fq => "{!term f=format_f v='Database & Article Index'}"},
        '3D object' => { :label => '3D object', :fq => "{!term f=format_f v='3D object'}"},
        'Projected graphic' => { :label => 'Projected graphic', :fq => "{!term f=format_f v='Projected graphic'}"},
    }
    #config.add_facet_field 'subject_taxonomy', label: 'Subject Taxonomy', collapse: false, :partial => 'blacklight/hierarchy/facet_hierarchy', :json_facet => SUBJECT_TAXONOM, :helper_method => :render_subcategories
    config.add_facet_field 'language_f', label: 'Language', limit: 5, collapse: false, :ex => 'orig_q', solr_params: MINCOUNT
    config.add_facet_field 'library_f', label: 'Library', limit: 5, collapse: false, :ex => 'orig_q', :if => local_only, solr_params: MINCOUNT
    config.add_facet_field 'specific_location_f', label: 'Specific location', limit: 5, :ex => 'orig_q', :if => local_only, solr_params: MINCOUNT
    config.add_facet_field 'recently_published', label: 'Recently published', collapse: false, :ex => 'orig_q',
        solr_params: MINCOUNT, :query => {
        :last_5_years => { label: 'Last 5 years', fq: "pub_max_dtsort:[#{Date.current.year - 4}-01-01T00:00:00Z TO *]" },
        :last_10_years => { label: 'Last 10 years', fq: "pub_max_dtsort:[#{Date.current.year - 9}-01-01T00:00:00Z TO *]" },
        :last_15_years => { label: 'Last 15 years', fq: "pub_max_dtsort:[#{Date.current.year - 14}-01-01T00:00:00Z TO *]" },
    }
    config.add_facet_field 'publication_date_f', label: 'Publication date', limit: 5, :ex => 'orig_q', solr_params: MINCOUNT
    config.add_facet_field 'classification_f', label: 'Classification', limit: 5, collapse: false, :ex => 'orig_q', :if => local_only, solr_params: MINCOUNT
    config.add_facet_field 'genre_f', label: 'Form/Genre', limit: 5, :ex => 'orig_q', solr_params: MINCOUNT
    config.add_facet_field 'recently_added_f', label: 'Recently added', solr_params: MINCOUNT, :if => local_only, :query => {
        :within_90_days => { label: 'Within 90 days', fq: "recently_added_isort:[#{PennLib::Util.today_midnight - (90 * SECONDS_PER_DAY) } TO *]" },
        :within_60_days => { label: 'Within 60 days', fq: "recently_added_isort:[#{PennLib::Util.today_midnight - (60 * SECONDS_PER_DAY) } TO *]" },
        :within_30_days => { label: 'Within 30 days', fq: "recently_added_isort:[#{PennLib::Util.today_midnight - (30 * SECONDS_PER_DAY) } TO *]" },
        :within_15_days => { label: 'Within 15 days', fq: "recently_added_isort:[#{PennLib::Util.today_midnight - (15 * SECONDS_PER_DAY) } TO *]" },
    }

    #config.add_facet_field 'example_pivot_field', label: 'Pivot Field', :pivot => ['format_f', 'language_f']
    # config.add_facet_field 'example_query_facet_field', label: 'Publish Date', :query => {
    #     :years_5 => { label: 'within 5 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 5 } TO *]" },
    #     :years_10 => { label: 'within 10 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 10 } TO *]" },
    #     :years_25 => { label: 'within 25 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 25 } TO *]" }
    # }
    # config.add_facet_field 'pub_date_isort', label: 'Publication Year', range: true, collapse: false,
    #                        include_in_advanced_search: false

    config.add_facet_field 'subject_xfacet2', label: 'Subject', limit: 20, show: false, solr_params: MINCOUNT,
                           xfacet: true, xfacet_view_type: 'xbrowse', facet_for_filtering: 'subject_f',
                           :if => search_field_accept::(['subject_xfacet2'])
    config.add_facet_field 'title_xfacet', label: 'Title', limit: 20, show: false, solr_params: MINCOUNT,
                           xfacet: true, xfacet_view_type: 'rbrowse', :if => search_field_accept::(['title_xfacet']),
                           xfacet_rbrowse_fields: %w(title author_creator_a standardized_title_a edition conference_a series contained_within_a publication_a format_a full_text_links_for_cluster_display availability)
    #config.add_facet_field 'author_creator_xfacet', label: 'Author', limit: 20, show: false,
    #                       xfacet: true, xfacet_view_type: 'xbrowse', facet_for_filtering: 'author_creator_f'
    config.add_facet_field 'author_creator_xfacet2', label: 'Author', limit: 20, show: false, solr_params: MINCOUNT,
                           xfacet: true, xfacet_view_type: 'xbrowse', facet_for_filtering: 'author_creator_f',
                           :if => search_field_accept::(['author_creator_xfacet2'])
    config.add_facet_field 'call_number_xfacet', label: 'Call number', limit: 20, show: false, solr_params: MINCOUNT,
                           xfacet: true, xfacet_view_type: 'rbrowse', :if => search_field_accept::(['call_number_xfacet']),
                           xfacet_rbrowse_fields: %w(title author_creator_a standardized_title_a edition conference_a series contained_within_a publication_a format_a full_text_links_for_cluster_display availability)

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    is_field_present = lambda { |context, field_config, document|
      document.fetch(field_config.field, nil).present? ||
          (document.respond_to?(field_config.field.to_sym) && document.send(field_config.field.to_sym).present?)
    }

    # we can't use def from inside the configure_blacklight block,
    # so this is a lambda
    add_fields = lambda { |config, field_type, field_defs|
      field_defs.each do |record|
        field_struct = record.dup
        if field_struct[:dynamic_name].present?
          name = field_struct.delete(:dynamic_name)
          defaults = {
              accessor: name,
              helper_method: 'render_values_with_breaks',
              if: is_field_present
          }
        else
          name = field_struct.delete(:name)
          defaults = {
              helper_method: 'render_values_with_breaks',
          }
        end
        if field_type == 'show'
          config.add_show_field(name, **defaults.merge(field_struct))
        elsif field_type == 'index'
          config.add_index_field(name, **defaults.merge(field_struct))
        end
      end
    }

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    add_fields.call(config, 'index', [
        { name: 'author_creator_a', label: 'Author/Creator', helper_method: 'render_author_with_880' },
        { name: 'standardized_title_a', label: 'Standardized Title' },
        { name: 'edition', label: 'Edition' },
        { name: 'conference_a', label: 'Conference name' },
        { name: 'series', label: 'Series' },
        { name: 'publication_a', label: 'Publication' },
        { dynamic_name: 'production_display', label: 'Production' },
        { dynamic_name: 'distribution_display', label: 'Distribution' },
        { dynamic_name: 'manufacture_display', label: 'Manufacture' },
        { name: 'contained_within_a', label: 'Contained in' },
        { name: 'format_a', label: 'Format/Description' },
        # in this view, 'Online resource' is full_text_link; note that
        # 'Online resource' is deliberately different here from what's on show view
        { dynamic_name: 'full_text_links_for_cluster_display', label: 'Online resource', helper_method: 'render_online_resource_display_for_index_view' },
    ])

    # Most show field values are generated dynamically from MARC stored in Solr.
    # This is because there's sometimes complex logic for extracting granular bits
    # used for linking, which differs from fields stored in Solr for faceting/search.
    #
    # For brevity and DRY, we define show fields in a data-driven way, following a few conventions:
    #
    #   name/dynamic_name: use one or the other, depending on whether field value(s)
    #       are dynamically generated on-the-fly, or a regular Solr field
    #   accessor: if dynamic, set to same string as 'dynamic_name'. This is the name
    #       of the method that gets called on the SolrDocument
    #   helper_method: defaults to 'render_values_with_breaks' if not specified.
    #       helper_method is used to render values for presentation.
    #   if: if dynamic, defaults to 'is_field_present' lambda if not specified,
    #       so that only fields containing non-blank values are displayed.

    add_fields.call(config, 'show', [
        { dynamic_name: 'author_display', label: 'Author/Creator', helper_method: 'render_linked_values' },
        { dynamic_name: 'standardized_title_display', label: 'Standardized Title', helper_method: 'render_linked_values' },
        { dynamic_name: 'other_title_display', label: 'Other Title' },
        { dynamic_name: 'edition_display', label: 'Edition' },
        { dynamic_name: 'publication_display', label: 'Publication' },
        { dynamic_name: 'production_display', label: 'Production' },
        { dynamic_name: 'distribution_display', label: 'Distribution' },
        { dynamic_name: 'manufacture_display', label: 'Manufacture' },
        { dynamic_name: 'conference_display', label: 'Conference Name', helper_method: 'render_linked_values' },
        { dynamic_name: 'series_display', label: 'Series', helper_method: 'render_linked_values' },
        { dynamic_name: 'format_display', label: 'Format/Description' },
        { dynamic_name: 'cartographic_display', label: 'Cartographic Data' },
        { dynamic_name: 'fingerprint_display', label: 'Fingerprint' },
        { dynamic_name: 'arrangement_display', label: 'Arrangement' },
        { dynamic_name: 'former_title_display', label: 'Former title', helper_method: 'render_linked_values' },
        { dynamic_name: 'continues_display', label: 'Continues' },
        { dynamic_name: 'continued_by_display', label: 'Continued By' },
        { dynamic_name: 'subject_display', label: 'Subjects', helper_method: 'render_linked_values' },
        { dynamic_name: 'children_subject_display', label: 'Childrens subjects', helper_method: 'render_linked_values' },
        { dynamic_name: 'medical_subject_display', label: 'Medical subjects', helper_method: 'render_linked_values' },
        { dynamic_name: 'local_subject_display', label: 'Local subjects', helper_method: 'render_linked_values' },
        { dynamic_name: 'genre_display', label: 'Form/Genre', helper_method: 'render_linked_values' },
        { dynamic_name: 'place_of_publication_display', label: 'Place of Publication', helper_method: 'render_linked_values' },
        { dynamic_name: 'language_display', label: 'Language' },
        { dynamic_name: 'system_details_display', label: 'System Details' },
        { dynamic_name: 'biography_display', label: 'Biography/History' },
        { dynamic_name: 'summary_display', label: 'Summary' },
        { dynamic_name: 'contents_display', label: 'Contents' },
        { dynamic_name: 'participant_display', label: 'Participant' },
        { dynamic_name: 'credits_display', label: 'Credits' },
        { dynamic_name: 'notes_display', label: 'Notes' },
        { dynamic_name: 'local_notes_display', label: 'Local notes' },
        { dynamic_name: 'offsite_display', label: 'Offsite' },
        { dynamic_name: 'finding_aid_display', label: 'Finding Aid/Index' },
        { dynamic_name: 'provenance_display', label: 'Penn Provenance', helper_method: 'render_linked_values' },
        { dynamic_name: 'chronology_display', label: 'Penn Chronology', helper_method: 'render_linked_values' },
        { dynamic_name: 'related_collections_display', label: 'Related Collections' },
        { dynamic_name: 'cited_in_display', label: 'Cited in' },
        { dynamic_name: 'publications_about_display', label: 'Publications about' },
        { dynamic_name: 'cite_as_display', label: 'Cited as' },
        { dynamic_name: 'contributor_display', label: 'Contributor', helper_method: 'render_linked_values' },
        { dynamic_name: 'related_work_display', label: 'Related Work' },
        { dynamic_name: 'contains_display', label: 'Contains' },
        { dynamic_name: 'other_edition_display', label: 'Other Edition', helper_method: 'render_linked_values' },
        { dynamic_name: 'contained_in_display', label: 'Contained In' },
        { dynamic_name: 'constituent_unit_display', label: 'Constituent Unit' },
        { dynamic_name: 'has_supplement_display', label: 'Has Supplement' },
        { dynamic_name: 'other_format_display', label: 'Other format' },
        { dynamic_name: 'isbn_display', label: 'ISBN' },
        { dynamic_name: 'issn_display', label: 'ISSN' },
        { name: 'oclc_id', label: 'OCLC' },
        { dynamic_name: 'publisher_number_display', label: 'Publisher Number' },
        { dynamic_name: 'web_link_display', label: 'Web link', helper_method: 'render_web_link_display' },
        { dynamic_name: 'access_restriction_display', label: 'Access Restriction' },
        { dynamic_name: 'bound_with_display', label: 'Bound with' },
        # 'Online' corresponds to the right-side box labeled 'Online' in DLA Franklin
        { dynamic_name: 'full_text_links_for_cluster_display', label: 'Online', helper_method: 'render_online_display_for_show_view' },
    #{ name: 'electronic_holdings_json', label: 'Online resource', helper_method: 'render_electronic_holdings' },
    ])

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.

    # Note that it's possible to specify a :qt argument on fields

    # BL search field names should be suffixed with _search and _xfacet where relevant,
    # in order for auto-generated search links on item page to work properly

    config.add_search_field 'keyword' do |field|
      field.label = 'Keyword'
      field.solr_local_parameters = {
          ps: '3',
          qf: 'marcrecord_xml^0.25 call_number_search^0.5 subject_search^1.0 title_1_search^2.5 title_2_search^1.5 author_creator_1_search^3 author_creator_2_search^2 isbn_isxn^0.25',
          pf: 'marcrecord_xml^0.25 call_number_search^0.5 subject_search^1.0 title_1_search^2.5 title_2_search^1.5 author_creator_1_search^3 author_creator_2_search^2 isbn_isxn^0.25'
      }
    end

    config.add_search_field 'keyword_expert' do |field|
      field.label = 'Keyword Expert (use: AND, OR, NOT, "phrase")'
      field.separator_beneath = true
      # TODO: where is 'dla-advanced' defined? right now this temporarily mirrors Keyword search, which isn't right.
      field.solr_local_parameters = {
          qf: 'marcrecord_xml^0.25 call_number_search^0.5 subject_search^1.0 title_1_search^2.5 title_2_search^1.5 author_creator_1_search^3 author_creator_2_search^2 isbn_isxn^0.25',
          pf: 'marcrecord_xml^0.25 call_number_search^0.5 subject_search^1.0 title_1_search^2.5 title_2_search^1.5 author_creator_1_search^3 author_creator_2_search^2 isbn_isxn^0.25'
      }
      field.include_in_advanced_search = false
    end

    config.add_search_field('title_xfacet') do |field|
      field.label = 'Title Browse (omit initial article: a, the, la, ...)'
      field.include_in_advanced_search = false
    end

    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    config.add_search_field('title_search') do |field|
      field.label = 'Title Keyword'
      # solr_parameters hash are sent to Solr as ordinary url query params.
      field.solr_parameters = { :'spellcheck.dictionary' => 'title_search' }

      # :solr_local_parameters will be sent using Solr LocalParams
      # syntax, as eg {! qf=$title_qf }. This is neccesary to use
      # Solr parameter de-referencing like $title_qf.
      # See: http://wiki.apache.org/solr/LocalParams
      field.solr_local_parameters = {
          qf: 'title_1_search^3 title_2_search^0.5',
          pf: 'title_1_search^3 title_2_search^0.5'
      }
    end

    config.add_search_field('journal_title_search') do |field|
      field.label = 'Journal Title Keyword'
      field.separator_beneath = true
      field.solr_parameters = { :'spellcheck.dictionary' => 'journal_title_search' }
      field.solr_local_parameters = {
          qf: 'journal_title_1_search^3 journal_title_2_search^0.5',
          pf: 'journal_title_1_search^3 journal_title_2_search^0.5'
      }
    end

    config.add_search_field('author_creator_xfacet2') do |field|
      field.label = 'Author Browse (last name first)'
      field.action = '/catalog/xbrowse/author_creator_xfacet2'
      field.include_in_advanced_search = false
    end

    config.add_search_field('author_search') do |field|
      field.label = 'Author Keyword'
      field.separator_beneath = true
      field.solr_parameters = { :'spellcheck.dictionary' => 'author_search' }
      field.solr_local_parameters = {
          qf: 'author_creator_1_search^3 author_creator_2_search^0.25',
          pf: 'author_creator_1_search^3 author_creator_2_search^0.25'
      }
    end

    config.add_search_field('subject_xfacet2') do |field|
      field.label = 'Subject Heading Browse'
      field.action = '/catalog/xbrowse/subject_xfacet2'
      field.include_in_advanced_search = false
    end

    config.add_search_field('subject_correlation') do |field|
      field.label = 'Subject Heading Correlation'
      #field.action = '/catalog/correlation/subject_correlation'
      field.solr_local_parameters = {
          tag: 'orig_q',
          qf: 'marcrecord_xml', # the most general text search we can get, to avoid spurious correlations
          pf: '' # domain only, no scoring, so pf doesn't matter
      }
      field.include_in_advanced_search = false
    end if ENABLE_SUBJECT_CORRELATION

    config.add_search_field('subject_search') do |field|
      field.label = 'Subject Heading Keyword'
      field.solr_parameters = { :'spellcheck.dictionary' => 'subject_search' }
      field.solr_local_parameters = {
          qf: 'subject_search^1.5',
          pf: 'subject_search^1'
      }
    end

    config.add_search_field('genre_search') do |field|
      field.label = 'Form/Genre Heading Keyword'
      field.separator_beneath = true
      field.solr_parameters = { :'spellcheck.dictionary' => 'genre_search' }
      field.solr_local_parameters = {
          qf: 'genre_search^1.5',
          pf: 'genre_search^1'
      }
    end

    config.add_search_field('call_number_xfacet') do |field|
      field.label = 'Call Number Browse'
      field.include_in_advanced_search = false
    end

    config.add_search_field('isxn_search') do |field|
      field.label = 'ISBN/ISSN'
      field.solr_parameters = { :'spellcheck.dictionary' => 'isbn_isxn' }
      field.solr_local_parameters = {
          qf: 'isbn_isxn^1'
      }
    end

    # only show these fields on Advanced Search

    config.add_search_field('series_search') do |field|
      field.label = 'Series'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'series_search',
          pf: 'series_search'
      }
    end

    config.add_search_field('publisher_search') do |field|
      field.label = 'Publisher'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'publisher_search',
          pf: 'publisher_search'
      }
    end

    config.add_search_field('place_of_publication_search') do |field|
      field.label = 'Place of publication'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'place_of_publication_search',
          pf: 'place_of_publication_search'
      }
    end

    config.add_search_field('conference_search') do |field|
      field.label = 'Conference'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'conference_search',
          pf: 'conference_search'
      }
    end

    config.add_search_field('corporate_author_search') do |field|
      field.label = 'Corporate author'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'corporate_author_search',
          pf: 'corporate_author_search'
      }
    end

    config.add_search_field('pubnum_search') do |field|
      field.label = 'Publisher number'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'pubnum_search',
          pf: 'pubnum_search'
      }
    end

    config.add_search_field('call_number_search') do |field|
      field.label = 'Call Number'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'call_number_search',
          pf: 'call_number_search'
      }
    end

    config.add_search_field('language_search') do |field|
      field.label = 'Language'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'language_search',
          pf: 'language_search'
      }
    end

    config.add_search_field('contents_note_search') do |field|
      field.label = 'Contents note'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'contents_note_search',
          pf: 'contents_note_search'
      }
    end

    config.add_search_field('id_search') do |field|
      field.label = 'ID'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'id',
          pf: 'id'
      }
    end

    config.add_search_field('mms_id') do |field|
      field.label = 'MMS ID'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'alma_mms_id',
          pf: 'alma_mms_id'
      }
    end

    config.add_search_field('publication_date_ssort') do |field|
      field.label = 'Publication Date (YYYY)'
      field.if = Proc.new { false }
      field.is_numeric_field = true
      field.include_in_advanced_search = true
      field.solr_local_parameters = {
          qf: 'publication_date_ssort',
          pf: 'publication_date_ssort'
      }
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    config.add_sort_field 'score desc', label: 'Relevance'
    config.add_sort_field 'title_nssort asc', label: 'Title (a-z)'
    config.add_sort_field 'title_nssort desc', label: 'Title (z-a)'
    config.add_sort_field 'author_creator_nssort asc', label: 'Author (a-z)'
    config.add_sort_field 'author_creator_nssort desc', label: 'Author (z-a)'
    config.add_sort_field 'publication_date_ssort desc, title_nssort asc', label: 'Pub date (new-old)'
    config.add_sort_field 'publication_date_ssort asc, title_nssort asc', label: 'Pub date (old-new)'
    config.add_sort_field 'recently_added_isort desc', label: 'Date added (new-old)'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = false
    config.autocomplete_path = 'suggest'

    add_show_tools_partial(:print, partial: 'print')

    config.show.document_actions.delete(:sms)

    PennLib::Util.reorder_document_actions(
        config.show.document_actions,
        :bookmark, :email, :citation, :print, :refworks, :endnote, :ris, :librarian_view)

    config.navbar.partials.delete(:search_history)
  end

  # extend 'index' so we can override views
  def bento
    params[:per_page] = 5
    index
  end

  # Landing has to live under this controller, otherwise the paths for
  # certain BL view partials used on landing page won't resolve correctly.
  def landing
    @page_title = t('franklin.landing_page_title')
    # only facets are needed, so set rows=0; we do need to grab these provisionally
    # because switching landing tabs happens by content hash, without network request
    # params[:per_page] = 0 #TODO: prevent this from being sticky!
    index
  end

  # override
  def search_results(user_params)
    sid = session&.id
    if !sid.nil? && sid.length >= 8
      routingHash = [sid[-8..-1]].pack("H*").unpack("l>")[0]
      # mod 12 to support even distribution for replication
      # factors 1,2,3,4; that should be sufficient for all
      # practical cases.
      user_params[:routingHash] = routingHash % 12
    end
    super
  end

  private

  def has_shib_session?
    session[:alma_sso_user].present?
  end

  def shib_session_valid?
    session[:alma_sso_user] == request.headers['HTTP_REMOTE_USER']
  end

  # should return true if page isn't protected behind Shib
  def is_unprotected_url?
    true
  end

  def expire_shib_session_return_url
    is_unprotected_url? ? request.original_url : root_url
  end

  # manually expire the session if user has exceeded 'hard expiration' or if
  # shib session has become inactive
  def expire_session
    invalid_shib = has_shib_session? && !shib_session_valid?
    if (session[:hard_expiration] && session[:hard_expiration] < Time.now.to_i) || invalid_shib
      reset_session
      url = invalid_shib ? "/Shibboleth.sso/Logout?return=#{URI.encode(expire_shib_session_return_url)}" : expire_shib_session_return_url
      redirect_to url, alert: 'Your session has expired, please log in again'
    end
  end

  def limit_facet_pagination
    if params['facet.page'] && params['facet.page'].to_i > FACET_PAGINATION_THRESHOLD
      flash[:error] = "You have paginated too deep into facets. Please contact us if you need to view facets past page #{FACET_PAGINATION_THRESHOLD}."
      redirect_to root_path
    end
  end

  def limit_index_pagination
    per_page = (params[:per_page] || params[:rows])&.to_i || blacklight_config.default_per_page
    if per_page > blacklight_config.max_per_page
      # somebody's hacking the url; they're not going to get more than MAX_PER_PAGE records anyway, so give them an error.
      # if it's a real person, they can resubmit the request and get what they would have gotten anyway; but don't jump through
      # hoops to return records to what's most likely an overly-curious crawler
      flash[:error] = "Request exceeds maximum number of records per page: #{blacklight_config.max_per_page}."
      redirect_to root_path
    elsif ((params[:page]&.to_i || 1) * per_page) > PAGINATION_THRESHOLD
      flash[:error] = "You have paginated too deep into the result set. Please contact us if you need to view results past record #{PAGINATION_THRESHOLD}."
      redirect_to root_path
    end
  end

  def limit_show_pagination
    if (counter = search_session['counter']&.to_i) && counter > PAGINATION_THRESHOLD
      Honeybadger.notify "Blocked attempt to paginate to record #{counter} (PAGINATION_THRESHOLD=#{PAGINATION_THRESHOLD})"
      flash[:error] = "You have paginated too deep into the result set. Please contact us if you need to view results past record #{PAGINATION_THRESHOLD}."
      redirect_to root_path
    end
  end

  ALIAS_SORT_FIELD = {
    # For now we will continue to transparently support links that might plausibly have been legit at
    # some point, by internally aliasing to the current field name. The right way to do this is
    # probably via 301 redirect to bridge a onetime migration to a more stable naming abstraction
    'title_ssort asc' => 'title_nssort asc',
    'title_ssort desc' => 'title_nssort desc',
    'author_creator_ssort asc' => 'author_creator_nssort asc',
    'author_creator_ssort desc' => 'author_creator_nssort desc',
    'publication_date_ssort asc, title_ssort asc' => 'publication_date_ssort asc, title_nssort asc',
    'publication_date_ssort desc, title_ssort asc' => 'publication_date_ssort desc, title_nssort asc'
  }

  def block_invalid_sort_params
    sort_val = params[:sort]
    return unless sort_val
    if aliased_sort_val = ALIAS_SORT_FIELD[sort_val]
      params[:sort] = aliased_sort_val
    elsif !blacklight_config.sort_fields.has_key?(sort_val)
      flash[:error] = "Requested illegal sort val: #{sort_val}"
      redirect_to root_path
    end
  end

  # override from Blacklight::Marc::Catalog so that action appears on bookmarks page
  def render_refworks_action?(config, options = {})
    doc = options[:document] || (options[:document_list] || []).first
    doc && doc.respond_to?(:export_formats) && doc.export_formats.keys.include?(:refworks_marc_txt)
  end

  def render_saved_searches?
    # don't ever show saved searches link to the user
    false
  end

end
