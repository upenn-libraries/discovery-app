
class FranklinAlmaController < BlacklightAlma::AlmaController

  #TODO: Move result ordering logic to concern?
  @@toplist = {'collection' => {}, 'interface' => {}}
  @@toplist['collection']['Publisher website'] = 8
  @@toplist['interface']['Highwire Press'] = 7
  @@toplist['interface']['HighWire'] = 6
  @@toplist['interface']['Elsevier ScienceDirect'] = 5
  @@toplist['interface']['Elsevier ClinicalKey'] = 4
  @@toplist['collection']['Vogue Magazine Archive'] = 3
  @@toplist['interface']['Nature'] = 2
  @@toplist['collection']['Academic OneFile'] = 1

  @@bottomlist = {'collection' => {}, 'interface' => {}}
  @@bottomlist['interface']['JSTOR'] = 1
  @@bottomlist['interface']['EBSCO Host'] = 2
  @@bottomlist['interface']['EBSCOhost'] = 3
  @@bottomlist['collection']['LexisNexis Academic'] = 4
  @@bottomlist['collection']['Factiva'] = 5
  @@bottomlist['collection']['Gale Cengage GreenR'] = 6
  @@bottomlist['collection']['Nature Free'] = 7
  @@bottomlist['collection']['DOAJ Directory of Open Access Journals'] = 8
  @@bottomlist['collection']['Highwire Press Free'] = 9
  @@bottomlist['collection']['Biography In Context'] = 10

  def cmpOnlineServices(service_a, service_b)
    collection_a = service_a['collection']
    interface_a = service_a['interface_name']
    collection_b = service_b['collection']
    interface_b = service_b['interface_name']

    score_a = -[@@toplist['collection'][collection_a] || 0, @@toplist['interface'][interface_a] || 0].max
    score_a = [@@bottomlist['collection'][collection_a] || 0, @@bottomlist['interface'][interface_a] || 0].max if score_a == 0

    score_b = -[@@toplist['collection'][collection_b] || 0, @@toplist['interface'][interface_b] || 0].max
    score_b = [@@bottomlist['collection'][collection_b] || 0, @@bottomlist['interface'][interface_b] || 0].max if score_b == 0

    return (score_a == score_b ? collection_a <=> collection_b : score_a <=> score_b)
  end

  def cmpHoldingLocations(holding_a, holding_b)
    lib_a = holding_a['library_code']
    lib_b = holding_b['library_code']

    score_a = lib_a == 'Libra' ? 1 : 0
    score_b = lib_b == 'Libra' ? 1 : 0

    return (score_a == score_b ? lib_a <=> lib_b : score_a <=> score_b)
  end

  def alma_api_class
    PennLib::BlacklightAlma::AvailabilityApi
  end

  def single_availability
    mmsid = params[:mmsid]
    userid = session['id'] || session[:alma_sso_user] || 'GUEST'
    api = alma_api_class.new()
    response_data = api.get_availability([mmsid])
    request_options = ['Hold Request', 'Interlibrary Loan', 'Books by Mail', 'Place on Course Reserve', 'Request Fix / Enhance Record', 'Scan &amp; Deliver', 'Send us a Question']
    table_data = response_data['availability'][mmsid]['holdings'].select { |h| h['inventory_type'] == 'physical' }
                 .sort { |a,b| cmpHoldingLocations(a,b) }
                 .each_with_index
                 .map { |h,i| [i, h['location'], h['availability'], h['call_number'], '<a href="#">View Shelf Location</a>'] }

    #render :json => {"data": [["Location of #{mmsid}", 'Availability', 'Call #', 'Details button']]}
    render :json => {"data": table_data}
  end

  # TODO: move into blacklight_alma gem (availability.rb concern)
  def availability
    if params[:id_list].present?
      api = alma_api_class.new()
      id_list = params[:id_list].split(',');
      response_data = api.get_availability(id_list)

      if response_data.dig('availability', id_list.first, 'holdings', 0, 'inventory_type') == 'electronic'
        response_data['availability'].keys.each { |mmsid|
          response_data['availability'][mmsid]['holdings'].sort! do |a,b|
            cmpOnlineServices(a,b)
          end
        }
      else
        response_data['availability'].keys.each { |mmsid|
          response_data['availability'][mmsid]['holdings'].sort! do |a,b|
            cmpHoldingLocations(a,b)
          end
        }
      end
    else
      response_data = {
          'error' => 'No id_list parameter'
      }
    end

    respond_to do |format|
      format.xml  { render :xml => response_data }
      format.json { render :json => response_data }
    end
  end

end
