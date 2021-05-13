module ApplicationHelper

  # Returns value of query param, preferring 'q' over 'query' and returning
  # an empty string if neither are present. mostly this is to please
  # bento_search view helper, which raises an exception with a nil param
  # @return [String]
  def query_param_value
    params[:q] || params[:query] || ''
  end

  def summon_url(query, proxy = false)
    url = "http://upenn.summon.serialssolutions.com/#!/search?q=#{url_encode(query)}"
    if proxy
      return "https://proxy.library.upenn.edu/login?url=#{url}"
    else
      return url
    end
  end

  # Path for a BL catalog index page with Databases facet applied
  # @return [String]
  # @param [String] query param
  def databases_results_path(query)
    search_catalog_path params: {
      q: query, utf8: '✓', search_field: 'keyword',
      'f[format_f][]': 'Database & Article Index'
    }
  end

  def google_site_search_results_url(query)
    return "https://www.library.upenn.edu/search/web-pages?q=#{query}"
  end

  def colenda_search_results_url(query)
    return "https://colenda.library.upenn.edu/catalog?q=#{query}"
  end

  def catalog_results_url(query)
    return search_catalog_path(q: query, search_field: 'keyword')
  end
  # returns the css classes needed for elements that should be considered 'active'
  # with respect to tabs functionality
  def active_tab_classes(tab_id)

    # treat bento as special case; almost everything else falls through to catalog
    on_bento_page = (controller_name == 'catalog') && ['landing', 'bento'].member?(action_name)

    # databases search, falls through to catalog but different tab should be highlighted
    on_databases_page = params.dig('f', 'format_f')&.include?('Database & Article Index')

    if tab_id == 'bento' && on_bento_page
      'active'
    elsif tab_id == 'databases' && on_databases_page
      'active'
    elsif tab_id == 'catalog'
      if !on_bento_page && !on_databases_page
        'active'
      end
    end

  end

  # returns a link element to be used for the tab; this could be either an anchor
  # or a link to another page, depending on the needs of the view
  def render_tab_link(tab_id, tab_label, anchor, url, data_target)

    if params[:q] && controller_name == 'catalog' && action_name == 'bento'
      attrs = {
          'href': url,
          'class': "#{tab_id}-anchor"
      }
    elsif params[:q] || tab_id == 'databases' || !(controller_name == 'catalog' && action_name == 'landing')
      attrs = {
          'href': url
      }
    elsif tab_id == 'website' && action_name == 'landing'
      attrs = {
          'href': "http://www.library.upenn.edu/search/web-pages"
      }
    elsif tab_id == 'colenda' && action_name == 'landing'
      attrs = {
          'href': "https://colenda.library.upenn.edu"
      }
    else
      attrs = {
          'href': anchor,
          'aria-controls': (data_target || '').gsub('#', '').split(',').first,
          'data-target': data_target,
          'role': 'tab',
          'data-toggle': 'tab',
          'class': "tab-#{tab_id}",
      }
    end
    content_tag('a', tab_label, attrs)
  end

  # @return [TrueClass, FalseClass]
  def atom_request?
    params[:format] == 'atom'
  end

  def display_alma_fulfillment_iframe?(document)
    # we need to display the iframe even when there are no holdings,
    # because there are request options and other links we want to show.
    # we do NOT want to show the iframe for things without an MMS ID (e.g. Hathi)
    document.alma_mms_id.present?
    # old logic:
    #document.has_any_holdings?
  end

  def my_library_card_url
    "https://#{ ENV['ALMA_DELIVERY_DOMAIN'] }/discovery/account?vid=#{ ENV['ALMA_INSTITUTION_CODE'] }:Services&lang=en&section=overview"
  end

  def subject_url(subject)
    "https://www.library.upenn.edu/people/subject-specialists##{subject.dasherize}"
  end

  def bolded_subject_list(subjects, match)
    subjects.map do |s|
      if match.downcase.gsub(/[^a-z]|amp/, '') == s.downcase.gsub(/[^a-z]/, '')
        content_tag(:strong, s)
      else
        s
      end
    end
  end

  def refworks_bookmarks_path(opts = {})
    # we can't direct refworks to the user's bookmarks page since that's private.
    # so we construct an advanced search query instead to return the bookmarked records
    id_search_value = @document_list.map { |doc| doc.id }.join(' OR ')
    url = search_catalog_url(
      id_search: id_search_value,
      search_field: 'advanced',
      commit: 'Search',
      format: 'refworks_marc_txt')
    refworks_export_url(url: url)
  end

  # this method returns a data structure used to prepopulate the
  # advanced search form.
  # returns a maximum of num_fields, and a minimum of min fields
  def prepopulated_search_fields_for_advanced_search(num_fields, is_numeric: true, min: nil)
    min ||= num_fields

    # get all the search fields defined in Blacklight config, as a
    # Hash of string field names to Field objects
    fields = search_fields_for_advanced_search.select { |key, field_def|
      is_numeric ? field_def.is_numeric_field : !field_def.is_numeric_field
    }

    # create an array of just the string field names
    fieldnames = fields.keys

    # figure out, from #params, the 'simple search' that user did
    queried_fields = params.dup
    if queried_fields["search_field"].present?
      queried_fields[queried_fields["search_field"]] = queried_fields["q"]
    end
    queried_fields = queried_fields.select { |k,v| fieldnames.member? k }
    queried_fields.sort

    preselection_candidates = fields.keys

    # now make an Array of OpenStructs for each row corresponding to a
    # set of form inputs, for advanced search page
    limit = 5
    i = 0
    result = []
    while i < limit do
      value = value2 = nil
      selected_field = preselection_candidates.first
      if queried_fields.length > 0
        fieldname = queried_fields.keys.first
        selected_field = fieldname
        # if there are multiple searches under the same field name
        if queried_fields[fieldname].kind_of? Array
          range_str = queried_fields[fieldname].first
          if !fields[fieldname].is_numeric_field
            value = range_str
          else
            range_str = queried_fields[fieldname].first
            match = /\[(\d+)\s+TO\s+(\d+)\]/.match(range_str)
            if match
              value, value2 = match[1], match[2]
            end
          end
          i += 1
          queried_fields[fieldname].delete(range_str)
          if queried_fields[fieldname].length <= 0
            queried_fields.delete(fieldname)
          end
          # otherwise, for non-numeric fields
        elsif !fields[fieldname].is_numeric_field
          value = queried_fields[fieldname]
          queried_fields.delete(fieldname)
          i += 1
        else
          range_str = queried_fields[fieldname]
          match = /\[(\d+)\s+TO\s+(\d+)\]/.match(range_str)
          if match
            value, value2 = match[1], match[2]
          end
          queried_fields.delete(fieldname)
          i += 1
        end
      else
        i += 1
      end
      if value || value2 || (result.size < min)
        preselection_candidates.delete(selected_field)
        result += [OpenStruct.new(
          index: i - 1,
          fields: fields,
          selected_field: selected_field,
          value: value,
          value2: value2,
        )]
      end
    end
    return result
  end

  def resourcesharing_path
    '/forms/resourcesharing'
  end
end
