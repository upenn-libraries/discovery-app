# frozen_string_literal: true
class CatalogController < ApplicationController
  include BlacklightAdvancedSearch::Controller

  include BlacklightRangeLimit::ControllerOverride

  include Blacklight::Catalog
  include Blacklight::Marc::Catalog

  include BlacklightSolrplugins::XBrowse

  configure_blacklight do |config|
    # default advanced config values
    config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # config.advanced_search[:qt] ||= 'advanced'
    config.advanced_search[:url_key] ||= 'advanced'
    config.advanced_search[:query_parser] ||= 'dismax'
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
      # TODO: this is annoying, but we do this: 1) to avoid pulling in large fields
      # unnecessarily, 2) to avoid hard-coding this list as a default value for 'fl'
      # in solrconfig.xml (which is how the Solr config that ships with BL does it)
      fl: %w{
        id
        score
        format
        isbn_isxn
        language_a
        title
        author_a
        standardized_title_a
        edition
        conference_a
        series
        publication_a
        contained_within_a
        subject_topic_a
        url_fulltext_display_a
        url_suppl_display_a
        physical_holdings_json
        electronic_holdings_json
      }.join(','),
      'facet.threads': 2,
      rows: 10
    }

    # solr path which will be added to solr base url before the other solr params.
    #config.solr_path = 'select'

    # items to show per page, each number in the array represent another option to choose from.
    #config.per_page = [10,20,50,100]

    ## Default parameters to send on single-document requests to Solr. These settings are the Blackligt defaults (see SearchHelper#solr_doc_params) or
    ## parameters included in the Blacklight-jetty document requestHandler.
    #
    #config.default_document_solr_params = {
    #  qt: 'document',
    #  ## These are hard-coded in the blacklight 'document' requestHandler
    #  # fl: '*',
    #  # rows: 1
    #  # q: '{!term f=id v=$id}'
    #}

    # solr field configuration for search results/index views
    config.index.title_field = 'title'
    config.index.display_type_field = 'format'

    # solr field configuration for document/show views
    #config.show.title_field = 'title_display'
    #config.show.display_type_field = 'format'

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

    config.add_facet_field 'access_f', label: 'Access'
    config.add_facet_field 'format_f', label: 'Format'
    config.add_facet_field 'author_f', label: 'Author/Creator', limit: 5, index_range: 'A'..'Z'
    config.add_facet_field 'subject_f', label: 'Subject', limit: 5, index_range: 'A'..'Z'
    config.add_facet_field 'language_f', label: 'Language', limit: true
    config.add_facet_field 'library_f', label: 'Library', limit: true
    config.add_facet_field 'specific_location_f', label: 'Specific location', limit: true
    config.add_facet_field 'publication_date_f', label: 'Publication date', limit: true
    config.add_facet_field 'classification_f', label: 'Classification', limit: true
    config.add_facet_field 'genre_f', label: 'Form/Genre', limit: true

    #config.add_facet_field 'example_pivot_field', label: 'Pivot Field', :pivot => ['format_f', 'language_f']
    # config.add_facet_field 'example_query_facet_field', label: 'Publish Date', :query => {
    #     :years_5 => { label: 'within 5 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 5 } TO *]" },
    #     :years_10 => { label: 'within 10 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 10 } TO *]" },
    #     :years_25 => { label: 'within 25 Years', fq: "pub_date_isort:[#{Time.zone.now.year - 25 } TO *]" }
    # }
    # config.add_facet_field 'pub_date_isort', label: 'Publication Year', range: true, collapse: false,
    #                        include_in_advanced_search: false

    config.add_facet_field 'subject_topic_xfacet', label: 'Topic', limit: 20, index_range: 'A'..'Z', show: false, xfacet: true, facet_for_filtering: 'subject_topic_f'
    config.add_facet_field 'title_xfacet', label: 'Title', limit: 20, index_range: 'A'..'Z', show: false, xfacet: true,
                           xfacet_rbrowse_fields: %w(publication format)
    config.add_facet_field 'author_xfacet', label: 'Author', limit: 20, index_range: 'A'..'Z', show: false, xfacet: true

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    config.add_index_field 'author_a', label: 'Author/Creator'
    config.add_index_field 'standardized_title_a', label: 'Standardized Title'
    config.add_index_field 'edition', label: 'Edition'
    config.add_index_field 'conference_a', label: 'Conference name'
    config.add_index_field 'series', label: 'Series'
    config.add_index_field 'publication_a', label: 'Publication'
    config.add_index_field 'contained_within_a', label: 'Contained in'
    config.add_index_field 'format', label: 'Format/Description'
    config.add_index_field 'electronic_holdings_json', label: 'Online resource', helper_method: 'render_electronic_holdings'

    is_field_present = lambda { |context, field_config, document|
      document.send(field_config.field.to_sym).present?
    }

    # Many of our show field values are generated dynamically from MARC stored in Solr
    # This is because there's sometimes complex logic for extracting granular bits
    # used for linking, which differs from fields stored in Solr for faceting/search.
    # Hence all the fields here that use 'accessor' to make calls on the SolrDocument object.

    config.add_show_field 'author_display', label: 'Author/Creator',
                          accessor: 'author_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'standardized_title_display', label: 'Standardized Title',
                          accessor: 'standardized_title_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'other_title_display', label: 'Other Title',
                          accessor: 'other_title_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'edition_display', label: 'Edition',
                          accessor: 'edition_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'publication_display', label: 'Publication',
                          accessor: 'publication_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'distribution_display', label: 'Distribution',
                          accessor: 'distribution_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'manufacture_display', label: 'Manufacture',
                          accessor: 'manufacture_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'conference_display', label: 'Conference Name',
                          accessor: 'conference_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'series_display', label: 'Series',
                          accessor: 'series_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'format_display', label: 'Format/Description',
                          accessor: 'format_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'cartographic_display', label: 'Cartographic Data',
                          accessor: 'cartographic_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'fingerprint_display', label: 'Fingerprint',
                          accessor: 'fingerprint_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'arrangement_display', label: 'Arrangement',
                          accessor: 'arrangement_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'former_title_display', label: 'Former title',
                          accessor: 'former_title_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'continues_display', label: 'Continues',
                          accessor: 'continues_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'continued_by_display', label: 'Continued By',
                          accessor: 'continued_by_display', helper_method: 'render_values_with_breaks', if: is_field_present
    # TODO: Subjects (Childrens, Medical, Local, etc)
    config.add_show_field 'genre_display', label: 'Form/Genre',
                          accessor: 'genre_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'place_of_publication_display', label: 'Place of Publication',
                          accessor: 'place_of_publication_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'language_display', label: 'Language',
                          accessor: 'language_display', helper_method: 'render_values_with_breaks', if: is_field_present
    # TODO: System Details
    config.add_show_field 'biography_display', label: 'Biography/History',
                          accessor: 'biography_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'summary_display', label: 'Summary',
                          accessor: 'summary_display', helper_method: 'render_values_with_breaks', if: is_field_present
    # TODO: Contents
    config.add_show_field 'participant_display', label: 'Participant',
                          accessor: 'participant_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'credits_display', label: 'Credits',
                          accessor: 'credits_display', helper_method: 'render_values_with_breaks', if: is_field_present
    # TODO: Notes
    # TODO: Local Notes
    config.add_show_field 'finding_aid_display', label: 'Finding Aid/Index',
                          accessor: 'finding_aid_display', helper_method: 'render_values_with_breaks', if: is_field_present
    # TODO: Provenance / Chronology
    config.add_show_field 'related_collections_display', label: 'Related Collections',
                          accessor: 'related_collections_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'cited_in_display', label: 'Cited in',
                          accessor: 'cited_in_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'publications_about_display', label: 'Publications about',
                          accessor: 'publications_about_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'cite_as_display', label: 'Cited as',
                          accessor: 'cite_as_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'contributor_display', label: 'Contributor',
                          accessor: 'contributor_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'related_work_display', label: 'Related Work',
                          accessor: 'related_work_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'contains_display', label: 'Contains',
                          accessor: 'contains_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'other_edition_display', label: 'Other Edition',
                          accessor: 'other_edition_display', helper_method: 'render_linked_values', if: is_field_present
    config.add_show_field 'contained_in_display', label: 'Contained In',
                          accessor: 'contained_in_display', helper_method: 'render_values_with_breaks', if: is_field_present
    config.add_show_field 'constituent_unit_display', label: 'Constituent Unit',
                          accessor: 'constituent_unit_display', helper_method: 'render_values_with_breaks', if: is_field_present

    # Has supplement
    # Other format
    # ISBN
    # ISSN
    # OCLC
    # Publisher Number
    # Online (for Hathi)
    # Access restriction
    # Bound with

    config.add_show_field 'electronic_holdings_json', label: 'Online resource', helper_method: 'render_electronic_holdings'

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

    config.add_search_field 'all_fields' do |field|
      field.label = 'All Fields'
      field.solr_local_parameters = {
          qf: 'text_search',
          pf: 'text_search'
      }
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
        qf: 'title_search',
        pf: 'title_search'
      }
    end

    config.add_search_field('author') do |field|
      field.solr_parameters = { :'spellcheck.dictionary' => 'author' }
      field.solr_local_parameters = {
        qf: 'author',
        pf: 'author'
      }
    end

    # Specifying a :qt only to show it's possible, and so our internal automated
    # tests can test it. In this case it's the same as
    # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    config.add_search_field('subject') do |field|
      field.solr_parameters = { :'spellcheck.dictionary' => 'subject' }
      field.qt = 'search'
      field.solr_local_parameters = {
        qf: 'subject',
        pf: 'subject'
      }
    end

    config.add_search_field('author_xfacet') do |field|
      field.label = 'Author Browse (last name first)'
      field.action = '/catalog/xbrowse/author_xfacet'
      field.include_in_advanced_search = false
    end

    config.add_search_field('subject_topic_xfacet') do |field|
      field.label = 'Subject Heading Browse'
      field.action = '/catalog/xbrowse/subject_topic_xfacet'
      field.include_in_advanced_search = false
    end

    config.add_search_field('title_xfacet') do |field|
      field.label = 'Title Browse'
      field.action = '/catalog/rbrowse/title_xfacet'
      field.include_in_advanced_search = false
    end

    # only show these fields on Advanced Search

    config.add_search_field('blah') do |field|
      field.label = 'Blah'
      field.if = Proc.new { false }
      field.include_in_advanced_search = true
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    config.add_sort_field 'score desc, pub_date_isort desc, title_ssort asc', label: 'relevance'
    config.add_sort_field 'pub_date_isort desc, title_ssort asc', label: 'year'
    config.add_sort_field 'author_ssort asc, title_ssort asc', label: 'author'
    config.add_sort_field 'title_ssort asc, pub_date_isort desc', label: 'title'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = true
    config.autocomplete_path = 'suggest'

    config.index.document_actions.delete(:bookmark)
  end

  # extend 'index' so we can override views
  def bento
    index
  end

  # Landing has to live under this controller, otherwise the paths for
  # certain BL view partials used on landing page won't resolve correctly.
  def landing
    index
  end

end
