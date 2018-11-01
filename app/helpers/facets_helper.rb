# frozen_string_literal: true
module FacetsHelper
  include Blacklight::FacetsHelperBehavior

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
    return if options[:facet_type] != facet_config[:facet_type]
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
end
