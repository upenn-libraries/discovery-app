module Blacklight::HierarchyHelper
  # Putting bare HTML strings in a helper sucks. But in this case, with a
  # lot of recursive tree-walking going on, it's an order of magnitude faster
  # than either render(:partial) or content_tag
  def render_facet_hierarchy_item(facet_item, facet_config, level)
    field_name = facet_item.field
    subset = subfacet(level, facet_config, facet_item)
    li_class = subset.blank? ? 'h-leaf' : 'h-node'
    ul = ''
    li = if facet_in_params?(field_name, facet_item.value)
           render_selected_qfacet_value(field_name, facet_item, facet_config)
         else
           render_qfacet_value(field_name, facet_item, facet_config)
         end

    unless subset.blank?
      subul = subset.map do |subkey|
        render_facet_hierarchy_item(subkey, facet_config, level + 1)
      end.join('')
      ul = "<ul>#{subul}</ul>".html_safe
    end
    %(<li class="#{li_class}">#{li.html_safe}#{ul.html_safe}</li>).html_safe
  end

  # `facet_config[:sub_hierarchy]` specifies the keys that allow us to navigate down
  # through subfacets. If `level < hierarchy_components.size` then we know there is
  # another level of facets, and we retrieve it from the `parent_facet_item` subs using
  # the key specified for our current `level`
  def subfacet(level, facet_config, parent_facet_item)
    hierarchy_components = facet_config[:sub_hierarchy]
    return level < hierarchy_components.size ? parent_facet_item.subs&.[](hierarchy_components[level]) : nil
  end

  # @param [Blacklight::Configuration::FacetField] as defined in controller with config.add_facet_field (and with :partial => 'blacklight/hierarchy/facet_hierarchy')
  # @return [String] html for the facet tree
  def render_hierarchy(facet_config)
    parsed = @response.aggregations[facet_config.field]
    parsed.items.map do |facet_item|
      render_facet_hierarchy_item(facet_item, facet_config, 0)
    end.join("\n").html_safe
  end

  def render_qfacet_value(facet_solr_field, item, facet_config, options = {})
    val = facet_config.helper_method ? (send facet_config.helper_method, item.value) : item.value
    (link_to_unless(options[:suppress_link], val, path_for_facet(facet_solr_field, item.value), class: 'facet_select') + ' ' + render_facet_count(item.hits)).html_safe
  end

  # Standard display of a SELECTED facet value, no link, special span with class, and 'remove' button.
  def render_selected_qfacet_value(facet_solr_field, item, facet_config)
    remove_href = search_action_path(search_state.remove_facet_params(facet_solr_field, item.value))
    content_tag(:span, render_qfacet_value(facet_solr_field, item, facet_config, suppress_link: true), class: 'selected') + ' ' +
      link_to(content_tag(:span, '', class: 'glyphicon glyphicon-remove') +
              content_tag(:span, '[remove]', class: 'sr-only'),
              remove_href,
              class: 'remove'
             )
  end
end
