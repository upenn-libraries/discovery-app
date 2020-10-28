# frozen_string_literal: true
module FacetsHelper
  include Blacklight::FacetsHelperBehavior

  def get_display_facet_types
    agg = @response.aggregations
    hash = {}
    blacklight_config.facet_fields.values.each_with_object(hash) do |facet_config, hash|
      display_facet = agg[facet_config.field]
      next if display_facet.nil? || display_facet.items.empty? || !should_render_field?(facet_config, display_facet)
      facet_type = facet_config[:facet_type] || :default
      facet_type = facet_type.call(params) if facet_type.respond_to?(:lambda?)
      if fields_for_facet_type = hash[facet_type]
        facet_configs = fields_for_facet_type[:facet_configs]
      else
        facet_type_config = blacklight_config.facet_types[facet_type]
        next if facet_type_config[:sidebar] == false
        facet_configs = []
        fields_for_facet_type = hash[facet_type] = {
          :facet_type_config => facet_type_config,
          :facet_configs => facet_configs
        }
      end
      facet_configs << facet_config
    end
    hash.sort_by { |k, v| v[:facet_type_config][:priority] }
  end

  ##
  # Check if any of the given fields have values
  #
  # @param [Array<String>] fields
  # @param [Hash] options
  # @return [Boolean]
  def has_facet_values? fields = facet_field_names, options = {}
    facets_from_request(fields).any? { |display_facet| !display_facet.items.empty? && should_render_facet?(display_facet) }
  end

  ##
  # Renders a single section for facet limit with a specified
  # solr field used for faceting. Can be over-ridden for custom
  # display on a per-facet basis. 
  #
  # @param [Blacklight::Solr::Response::Facets::FacetField] display_facet 
  # @param [Hash] options parameters to use for rendering the facet limit partial
  # @option options [String] :partial partial to render
  # @option options [String] :layout partial layout to render
  # @option options [Hash] :locals locals to pass to the partial
  # @return [String] 
  def render_facet_limit(display_facet, options = {})
    facet_config = facet_configuration_for_field(display_facet.name)
    return unless should_render_facet?(display_facet)
    options = options.dup
    options[:partial] ||= facet_partial_name(display_facet)
    options[:layout] ||= facet_config.dig(:options, :layout) || "facet_layout" unless options.key?(:layout)
    options[:locals] ||= {}
    options[:locals][:field_name] ||= display_facet.name
    options[:locals][:solr_field] ||= display_facet.name # deprecated
    options[:locals][:facet_field] ||= facet_config
    options[:locals][:display_facet] ||= display_facet

    render(options)
  end

##
  # Renders the list of values 
  # removes any elements where render_facet_item returns a nil value. This enables an application
  # to filter undesireable facet items so they don't appear in the UI
  def render_facet_limit_list(paginator, facet_field, wrapping_element=:li, options={})
    safe_join(paginator.items.map { |item| render_facet_item(facet_field, item, options) }.compact.map { |item| content_tag(wrapping_element,item)})
  end

  ##
  # Renders a single facet item
  def render_facet_item(facet_field, item, options={})
    if facet_in_params?(facet_field, item.value )
      render_selected_facet_value(facet_field, item, options)
    else
      render_facet_value(facet_field, item, options)
    end
  end
  ##
  # Standard display of a facet value in a list. Used in both _facets sidebar
  # partial and catalog/facet expanded list. Will output facet value name as
  # a link to add that to your restrictions, with count in parens.
  #
  # @param [Blacklight::Solr::Response::Facets::FacetField] facet_field
  # @param [Blacklight::Solr::Response::Facets::FacetItem] item
  # @param [Hash] options
  # @option options [Boolean] :suppress_link display the facet, but don't link to it
  # @return [String]
  def render_facet_value(facet_field, item, options ={})
    path = path_for_facet(facet_field, item)
    content_tag(:span, :class => "facet-label") do
      link_to_unless((options[:suppress_link] || item.hits == 0), facet_display_value(facet_field, item), path, :class=>"facet_select")
    end + (options[:suppress_count] ? '' : render_facet_count(item.hits))
  end

  ##
  # Standard display of a SELECTED facet value (e.g. without a link and with a remove button)
  # @see #render_facet_value
  # @param [Blacklight::Solr::Response::Facets::FacetField] facet_field
  # @param [String] item
  def render_selected_facet_value(facet_field, item, options={})
    remove_href = search_action_path(search_state.remove_facet_params(facet_field, item))
    content_tag(:span, class: "facet-label") do
      content_tag(:span, facet_display_value(facet_field, item), class: "selected") +
      # remove link
      link_to(remove_href, class: "remove") do
        content_tag(:span, '', class: "glyphicon glyphicon-remove") +
        content_tag(:span, '[remove]', class: 'sr-only')
      end
    end + (options[:suppress_count] ? '' : render_facet_count(item.hits, :classes => ["selected"]))
  end


  ##
  # Determine if Blacklight should render the display_facet or not
  #
  # By default, only render facets with items.
  #
  # @param [Blacklight::Solr::Response::Facets::FacetField] display_facet
  # @return [Boolean] 
  def should_render_facet? display_facet
    # display when show is nil or true
    facet_config = facet_configuration_for_field(display_facet.name)
    display = should_render_field?(facet_config, display_facet)
    display && display_facet.items.present?
  end

  def render_subcategories(v)
    idx = v.index('--')
    idx.nil? ? v : v.slice((idx + 2)..-1)
  end

  # Display facet sort options for modal with active sort selected
  # @param [Blacklight::Solr::FacetPaginator] pagination
  # @return [ActiveSupport::SafeBuffer] links html
  def modal_sort_options(pagination, facet_config)
    sort_options = facet_config.sort_options&.call(params) || ['index', 'count']
    links = sort_options.map do |possible_sort|
      active = pagination.sort == possible_sort
      modal_sort_link possible_sort, active
    end
    links.join.html_safe
  end

  # Generate a link for a facet sort option
  # @param [String] type
  # @param [TrueClass, FalseClass] active
  # @return [ActiveSupport::SafeBuffer] link html
  def modal_sort_link(type, active)
    label = t "blacklight.search.facets.sort.#{type}"
    if active
      content_tag :span, label, class: 'active numeric btn btn-default'
    else
      link_to label,
              @pagination.params_for_resort_url(type, search_state.to_h),
              class: 'sort_change numeric btn btn-default',
              data: { ajax_modal: 'preserve' }
    end
  end
end
