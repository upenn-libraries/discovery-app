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
    elsif tab_id == 'catalog' && controller_name == 'catalog' && !on_bento_page
      'active'
    end
  end

  # returns a link element to be used for the tab; this could be either an anchor
  # or a link to another page, depending on the needs of the view
  def render_tab_link(tab_id, tab_label, anchor, url, data_target)
    if params[:q]
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

end
