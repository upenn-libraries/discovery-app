# Methods and constants to handle custom sorting of holdings responses
# from Alma API
module AlmaResultOrdering
  extend ActiveSupport::Concern

  # TODO: Explain...
  TOP_LIST = {
    collection: {
      'Academic OneFile' => 1,
      'Vogue Magazine Archive' => 3,
      'Publisher website' => 8
    },
    interface: {
      'Nature' => 2,
      'Elsevier ClinicalKey' => 4,
      'Elsevier ScienceDirect' => 5,
      'HighWire' => 6,
      'Highwire Press' => 7
    }
  }.freeze

  # TODO: Explain...
  BOTTOM_LIST = {
    collection: {
      'LexisNexis Academic' => 4,
      'Factiva' => 5,
      'Gale Cengage GreenR' => 6,
      'Nature Free' => 7,
      'DOAJ Directory of Open Access Journals' => 8,
      'Highwire Press Free' => 9,
      'Biography In Context' => 10
    },
    interface: {
      'JSTOR' => 1,
      'EBSCO Host' => 2,
      'EBSCOhost' => 3
    }
  }.freeze

  TOP_OPTIONS = {
    'Request' => 1
  }.freeze

  BOTTOM_OPTIONS = {
    'Suggest Fix / Enhance Record' => 1,
    'Place on Course Reserve' => 2
  }.freeze

  # @param [Hash] service_a
  # @param [Hash] service_b
  # @return [Fixnum]
  def compare_online_services(service_a, service_b)
    collection_a = service_a['collection'] || ''
    interface_a = service_a['interface_name'] || ''
    collection_b = service_b['collection'] || ''
    interface_b = service_b['interface_name'] || ''

    score_a = -[
      TOP_LIST[:collection][collection_a] || 0,
      TOP_LIST[:interface][interface_a] || 0
    ].max

    if score_a.zero?
      score_a = [
        BOTTOM_LIST[:collection][collection_a] || 0,
        BOTTOM_LIST[:interface][interface_a] || 0
      ].max
    end

    score_b = -[
      TOP_LIST[:collection][collection_b] || 0,
      TOP_LIST[:interface][interface_b] || 0
    ].max

    if score_b.zero?
      score_b = [
        BOTTOM_LIST[:collection][collection_b] || 0,
        BOTTOM_LIST[:interface][interface_b] || 0
      ].max
    end

    score_a == score_b ? collection_a <=> collection_b : score_a <=> score_b
  end

  # @param [Hash] holding_a
  # @param [Hash] holding_b
  # @return [Fixnum]
  def compare_holding_locations(holding_a, holding_b)
    lib_a = holding_a['library_code'] || ''
    lib_b = holding_b['library_code'] || ''

    score_a = lib_a == 'Libra' ? 1 : 0
    score_b = lib_b == 'Libra' ? 1 : 0

    score_a == score_b ? lib_a <=> lib_b : score_a <=> score_b
  end

  # @param [Hash] option_a
  # @param [Hash] option_b
  # @return [Fixnum]
  def compare_request_options(option_a, option_b)
    score_a = -top_option(option_a)
    score_a = bottom_option(option_a) if score_a.zero?

    score_b = -top_option(option_b)
    score_b = bottom_option(option_b) if score_b.zero?

    score_a <=> score_b
  end

  def top_option(option)
    TOP_OPTIONS[option[:option_name]] || 0
  end

  def bottom_option(option)
    BOTTOM_OPTIONS[option[:option_name]] || 0
  end
end
