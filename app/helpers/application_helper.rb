module ApplicationHelper

  def summon_url(query)
    # TODO
    return "http://upenn.summon.serialssolutions.com/search#!/search?q=#{url_encode(query)}"
  end

  # override Blacklight to replace the default bar (containing simple search form)
  # with our fancy tabbed search bar
  def render_search_bar
    render partial: 'catalog/franklin_search_bar'
  end

  # returns the css classes needed for elements that should be considered 'active'
  # with respect to tabs functionality
  def active_tab_classes(tab_id)
    # treat bento as special case; almost everything else falls through to catalog
    on_bento_page = (controller_name == 'catalog') && ['landing', 'bento'].member?(action_name)
    if tab_id == 'bento' && on_bento_page
      'active'
    elsif tab_id == 'catalog'
      if !on_bento_page
        'active'
      end
    end
  end

  # returns a link element to be used for the tab; this could be either an anchor
  # or a link to another page, depending on the needs of the view
  def render_tab_link(tab_id, tab_label, anchor, url, data_target)
    if params[:q] || !(controller_name == 'catalog' && action_name == 'landing')
      attrs = {
          'href': url
      }
    else
      attrs = {
          'href': anchor,
          'aria-controls': tab_id,
          'data-target': data_target,
          'role': 'tab',
          'data-toggle': 'tab',
          'class': "tab-#{tab_id}",
      }
    end
    content_tag('a', tab_label, attrs)
  end

  # override Blacklight so that 'index_document_append' and
  # 'show_document_append' partials are appended to the partials
  # that normally render for a document. This exists
  # to avoid having to copy-and-paste a stock BL template
  # when we want to append to it; that prevents us from
  # getting template updates when upgrading BL.
  def render_document_partial(doc, base_name, locals = {})
    result = super(doc, base_name, locals)
    if [:index, :show].member?(base_name)
      template = lookup_context.find_all("#{base_name}_document_append", lookup_context.prefixes + [""], true, locals.keys + [:document], {}).first
      if template
        result += template.render(self, locals.merge(document: doc))
      end
    end
    result
  end

  # suppress showing availability info, which we want to do in Test
  # currently but not Dev.
  # TODO: should be removed eventually
  def show_availability?
    !(ENV['SUPPRESS_AVAILABILITY'] == 'true')
  end

  # override Blacklight so Start Over always goes to catalog start page
  def start_over_path(query_params = params)
    # we do NOT call #search_action_path because it might take us to an
    # "blank" browse page, which is never what we want
    root_path
  end

  def facet_field_names_for_advanced_search
    # exclude pub date range facet, b/c it has a form, which nests insid
    # the advanced search form and causes havoc
    blacklight_config.facet_fields.values.select { |f| !f.xfacet && f.field != 'pub_date_isort' }.map(&:field)
  end

  def render_link_to_range_limit(solr_field, min, max)
    link_to('View distribution', params.merge(use_route: "blacklight_advanced_search_routes", :action => 'range_limit', :range_field => solr_field, :range_start => min, :range_end => max), :class => "load_distribution")
  end

end
