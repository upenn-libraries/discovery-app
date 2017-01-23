module ApplicationHelper

  def summon_url(query)
    # TODO
    return "http://upenn.summon.serialssolutions.com/search#!/search?q=#{url_encode(query)}"
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

  # return true if availability info HTML should be rendered (and loaded dynamically in-page)
  def show_availability?(document)
    # TODO: env var check should be removed eventually
    (ENV['SUPPRESS_AVAILABILITY'] != 'true') && document.has?(:physical_holdings_json)
  end

end
