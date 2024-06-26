# frozen_string_literal: true

# methods and constants for ordering alma request options, holdings, collections
# these methods are intended to be used along with sort calls
module AlmaOptionOrdering
  extend ActiveSupport::Concern

  # higher scores sort higher
  TOP_SERVICES = {
    collection: {
      'Publisher website' => 100,
      'The New Republic Archive' => 99,
      'Publishers Weekly Archive (1872- current)' => 98,
      'American Association for the Advancement of Science' => 97,
      'Vogue Magazine Archive' => 96,
      'ProQuest Historical Newspapers: The New York Times' => 95,
      'ProQuest Historical Newspapers: Pittsburgh Post-Gazette' => 94,
      'ProQuest Historical Newspapers: The Washington Post' => 93,
      'Wiley Online Library - Current Journals' => 88,
      'Academic OneFile' => 87,
      'Academic Search Premier' => 86
    },
    interface: {
      'Highwire Press' => 92,
      'Elsevier ScienceDirect' => 91,
      'Nature' => 90,
      'Elsevier ClinicalKey' => 89,
    }
  }.freeze

  # again, 'higher' scores sort higher
  BOTTOM_SERVICES = {
    collection: {
      'LexisNexis Academic' => -1,
      'Factiva' => -2,
      'Gale Cengage GreenR' => -3,
      'Nature Free' => -4,
      'DOAJ Directory of Open Access Journals' => -5,
      'Highwire Press Free' => -6,
      'Biography In Context' => -7
    },
    interface: {}
  }.freeze


  # used with Array#sort
  # services that are not included in top or bottom lists will both get 0 scores, and so be sorted alphabetically
  # services in the top list will get positive numeric scores
  # services in the bottom list will get negative numeric scores
  # returns a positive value if service_b should be ranked above service_a
  # returns a negative value if service_b should be ranked below service_a
  # if scores are identical...alphabetically sorted
  # top_service scores will be preferred
  # @param [Hash] service_a
  # @param [Hash] service_b
  # @return [Fixnum]
  def compare_services(service_a, service_b)
    collection_a = service_a['collection'] || ''
    interface_a = service_a['interface_name'] || ''
    collection_b = service_b['collection'] || ''
    interface_b = service_b['interface_name'] || ''

    score_a = [
      TOP_SERVICES[:collection][collection_a],
      TOP_SERVICES[:interface][interface_a],
      BOTTOM_SERVICES[:collection][collection_a],
      BOTTOM_SERVICES[:interface][interface_a]
    ].compact.max || 0

    score_b = [
      TOP_SERVICES[:collection][collection_b],
      TOP_SERVICES[:interface][interface_b],
      BOTTOM_SERVICES[:collection][collection_b],
      BOTTOM_SERVICES[:interface][interface_b]
    ].compact.max || 0

    if score_a == score_b
      collection_a <=> collection_b # compare alphabetically if scores are the same
    else
      score_b <=> score_a # compare by score otherwise
    end
  end

  # @param [Hash] holding_a
  # @param [Hash] holding_b
  # @return [Fixnum]
  def compare_holdings(holding_a, holding_b)
    lib_a = holding_a['library_code'] || ''
    lib_b = holding_b['library_code'] || ''

    score_a = lib_a == 'Libra' ? 1 : 0
    score_b = lib_b == 'Libra' ? 1 : 0

    if score_a == score_b
      lib_a <=> lib_b
    else
      score_a <=> score_b
    end
  end
end
