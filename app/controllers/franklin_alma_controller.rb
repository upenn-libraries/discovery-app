
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
    userid = session[:alma_sso_user] || (session['id'] != 'none' ? session['id'] : nil) || 'GUEST'
    api = alma_api_class.new()
    response_data = api.get_availability([mmsid])
    response_data['availability'][mmsid]['holdings'].each do |holding|
      if holding.key?('holding_info')
        holding['location'] = %Q[<a href="javascript:loadItems('#{mmsid}', '#{holding['holding_id']}')">#{holding['location']} &gt;</a>]
      end
    end

    request_options = ['Hold Request', 'Interlibrary Loan', 'Books by Mail', 'Place on Course Reserve', 'Request Fix / Enhance Record', 'Scan &amp; Deliver', 'Send us a Question']
    table_data = response_data['availability'][mmsid]['holdings'].select { |h| h['inventory_type'] == 'physical' }
                 .sort { |a,b| cmpHoldingLocations(a,b) }
                 .each_with_index
                 .map { |h,i| [i, h['location'], h['availability'], h['call_number'], '<a href="#">View Shelf Location</a>'] }

    #render :json => {"data": [["Location of #{mmsid}", 'Availability', 'Call #', 'Details button']]}
    render :json => {"data": table_data}
  end

  def holding_items
    userid = session[:alma_sso_user] || (session['id'] != 'none' ? session['id'] : nil)
    policy = 'Please log in for loan and request information' if userid.nil?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    options = {:expand => 'due_date_policy', :offset => 0, :limit => 100, :user_id => userid}
    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options))

    table_data = response_data['item'].each_with_index.map { |item, i|
      data = item['item_data']
      #[i, data['barcode'], data['physical_material_type']['desc'], policy || data['due_date_policy'], data['description'], data['base_status']['desc'], '']
      [data['pid'], data['description'], policy || data['due_date_policy'], data['base_status']['desc'], data['barcode'], '']
    }

    while options[:offset] + options[:limit] < response_data['total_record_count']
      options[:offset] += options[:limit]
      response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options))
      
      table_data += response_data['item'].each_with_index.map { |item, i|
        data = item['item_data']
        #[i, data['barcode'], data['physical_material_type']['desc'], policy || data['due_date_policy'], data['description'], data['base_status']['desc'], '']
        [data['pid'], data['barcode'], data['physical_material_type']['desc'], policy || data['due_date_policy'], data['description'], data['base_status']['desc'], '']
      }
    end

    render :json => {"data": table_data}
  end

  def request_options
    userid = session[:alma_sso_user] || (session['id'] != 'none' ? session['id'] : nil)
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    options = {:user_id => userid}
    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))
    results = response_data['request_option'].map { |option|
      request_url = option['request_url']
      type = option['type']
      details = option['general_electronic_service_details'] || option['rs_broker_details'] || {}

      if request_url.nil?
        nil
      else
        case option['type']['value']
        when 'HOLD'
          {
            :option_name => 'Request',
            :option_url => option['request_url'],
            :avail_for_physical => true,
            :avail_for_electronic => true
          }
        when 'GES'
          {
            :option_name => details['public_name'],
            :option_url => option['request_url'],
            :avail_for_physical => details['avail_for_physical'],
            :avail_for_electronic => details['avail_for_electronic']
          }
        when 'RS_BROKER'
          {
            :option_name => details['name'],
            :option_url => option['request_url'],
            :avail_for_physical => true,
            :avail_for_electronic => true
          }
        else
          nil
        end
      end
    } .compact

    render :json => results
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
