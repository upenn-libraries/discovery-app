# frozen_string_literal: true

# methods and constants for ordering alma request options, holdings, collections
# these methods are intended to be used along with sort calls
module AlmaOptionOrdering
  extend ActiveSupport::Concern

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

  BOTTOM_SERVICES = {
    collection: {
      'LexisNexis Academic' => 4,
      'Factiva' => 5,
      'Gale Cengage GreenR' => 6,
      'Nature Free' => 7,
      'DOAJ Directory of Open Access Journals' => 8,
      'Highwire Press Free' => 9,
      'Biography In Context' => 10
    },
    interface: {}
  }.freeze


  # a comparison between service_a and service_b that returns an integer less than 0 when service_b follows service_a,
  # 0 when service_a and service_b are equivalent, or an integer greater than 0 when service_a follows service_b
  # @param [Hash] service_a
  # @param [Hash] service_b
  # @return [Fixnum]
  def compare_services(service_a, service_b)
    collection_a = service_a['collection'] || ''
    interface_a = service_a['interface_name'] || ''
    collection_b = service_b['collection'] || ''
    interface_b = service_b['interface_name'] || ''

    score_a = -[TOP_SERVICES[:collection][collection_a] || 0, TOP_SERVICES[:interface][interface_a] || 0].max
    if score_a == 0
      score_a = [BOTTOM_SERVICES[:collection][collection_a] || 0, BOTTOM_SERVICES[:interface][interface_a] || 0].max
    end

    score_b = -[TOP_SERVICES[:collection][collection_b] || 0, TOP_SERVICES[:interface][interface_b] || 0].max
    if score_b == 0
      score_b = [BOTTOM_SERVICES[:collection][collection_b] || 0, BOTTOM_SERVICES[:interface][interface_b] || 0].max
    end

    if score_a == score_b
      collection_a <=> collection_b # compare alphabetically if scores are the same
    else
      score_a <=> score_b # compare by score otherwise
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
