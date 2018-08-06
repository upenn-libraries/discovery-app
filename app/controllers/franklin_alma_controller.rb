
#class FranklinAlmaController < BlacklightAlma::AlmaController
class FranklinAlmaController < ApplicationController

  include BlacklightAlma::Availability

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

  @@topoptionslist = {}
  @@topoptionslist['Request'] = 1

  @@bottomoptionslist = {}
  @@bottomoptionslist['Suggest Fix / Enhance Record'] = 1
  @@bottomoptionslist['Place on Course Reserve'] = 2

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

  def cmpRequestOptions(option_a, option_b)
    score_a = -(@@topoptionslist[option_a[:option_name]] || 0)
    score_a = (@@bottomoptionslist[option_a[:option_name]] || 0) if score_a == 0

    score_b = -(@@topoptionslist[option_b[:option_name]] || 0)
    score_b = (@@bottomoptionslist[option_b[:option_name]] || 0) if score_b == 0

    return score_a <=> score_b
  end

  def alma_api_class
    PennLib::BlacklightAlma::AvailabilityApi
  end

  def holding_details
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id, :get, params)

    xml = Nokogiri(response_data.body)
    holding_details = xml.xpath('//datafield[@tag="866"]/subfield[@code="a"]').map { |field|
                        field.text
                      }

    note_details = xml.xpath('//datafield[@tag="852"]/subfield[@code="z"]').map { |field|
                     field.text
                   }
    note_details.unshift('Public Notes:') unless note_details.empty?

    supplemental_details = xml.xpath('//datafield[@tag="867"]/subfield[@code="a"]').map { |field|
                             field.text
                           }
    supplemental_details.unshift('Supplemental:') unless supplemental_details.empty?

    index_details = xml.xpath('//datafield[@tag="868"]/subfield[@code="a"]').map { |field|
                      field.text
                    }
    index_details.unshift('Indexes:') unless index_details.empty?

    render :html => ('<span>' + (holding_details + note_details + supplemental_details + index_details).join("<br/>") + '</span>').html_safe

  end

  def single_availability
    availability_status = {'available' => 'Available',
                           'check_holdings' => 'Requestable'}

    mmsid = params[:mmsid]
    userid = session['id'].presence || 'GUEST'
    bibapi = alma_api_class.new()
    response_data = bibapi.get_availability([mmsid])
    holding_data = nil

    # Load holding information for monographs. Monographs do not have
    # a 'holding_info' value.
    unless response_data['availability'][mmsid]['holdings']&.dig(0, 'holding_info').present?
      api_instance = BlacklightAlma::BibsApi.instance
      api = api_instance.ezwadl_api[0]
      holding_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, :mms_id => mmsid, :holding_id => 'ALL', :expand => 'due_date_policy', :user_id => userid)
      holding_map = {}
      
      [holding_data['items']['item']].flatten.reject(&:nil?).each do |item|
        holding_id = item['holding_data']['holding_id']
        item_pid = item['item_data']['pid']
        due_date_policy = item['item_data']['due_date_policy']
        holding_map[holding_id] ||= {}
        holding_map[holding_id][:item_pid] = item_pid
        holding_map[holding_id][:due_date_policy] = due_date_policy
      end
    end

    response_data['availability'][mmsid]['holdings'].each do |holding|
      links = []
      links << "<a href='/redir/aeon?bibid=#{holding['mmsid']}&hldid=#{holding['holding_id']}'' target='_blank'>Request to view in reading room</a>" if holding['link_to_aeon']
      #links << "<span class='check-requestable' data-mmsid='#{params[:mmsid]}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/></span>"
      holding['availability'] = availability_status[holding['availability']] || 'Requestable'

      if holding.key?('holding_info')
        holding['location'] = %Q[<a href="javascript:loadItems('#{mmsid}', '#{holding['holding_id']}')">#{holding['location']} &gt;</a>]
        holding['availability'] = "<span class='load-holding-details' data-mmsid='#{params[:mmsid]}' data-holdingid='#{holding['holding_id']}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/></span>"
      else
        holding['item_pid'] = holding_map.dig(holding['holding_id'], :item_pid)
        holding['due_date_policy'] = holding_map.dig(holding['holding_id'], :due_date_policy)
      end

      holding['links'] = links
    end

    policy = 'Please log in for loan and request information' if userid == 'GUEST'
    table_data = response_data['availability'][mmsid]['holdings'].select { |h| h['inventory_type'] == 'physical' }
                 .sort { |a,b| cmpHoldingLocations(a,b) }
                 .each_with_index
                 .map { |h,i| [i, h['location'], policy || h['due_date_policy'], h['availability'], h['call_number'], h['links'], h['holding_id'], h['item_pid']] }

    #render :json => {"data": [["Location of #{mmsid}", 'Availability', 'Call #', 'Details button']]}
    render :json => {"data": table_data}
  end

  def check_requestable
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_requests, :get, params)
    result = {}

    if response_data.dig('total_record_count') != '0'
      [response_data.dig('user_requests', 'user_request')].flatten.reject(&:nil?).each do |req|
        item_pid = req.dig('item_id').presence
        request_type = req.dig('request_sub_type', '__content__').presence
        result[item_pid] ||= []
        result[item_pid] << request_type 
      end
    end

    render :json => result

  end

  def holding_items
    userid = session['id'].presence || nil
    due_date_policy = 'Please log in for loan and request information' if userid.nil?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    options = {:expand => 'due_date_policy', :offset => 0, :limit => 100, :user_id => userid}
    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options))

    if !response_data.key?('item')
      render :json => {"data": []}
      return
    end

    policies = {}
    pids_to_check = []

    table_data = response_data['item'].map { |item|
      data = item['item_data']
      unless(policies.has_key?(data['policy']['value']) || data['base_status']['desc'] != "Item in place")
        policies[data['policy']['value']] = nil
        pids_to_check << [data['pid'], data['policy']['value']]
      end
#      data['links'] = ["<a href='/alma/request?mms_id=#{params['mms_id']}&holding_id=#{params['holding_id']}&item_pid=#{data['pid']}' target='_blank'>Request</a>"] unless userid.nil?
      [data['policy']['value'], data['pid'], data['description'], due_date_policy || data['due_date_policy'], data['base_status']['desc'], data['barcode'], [], params['mms_id'], params['holding_id']]
    }

    while options[:offset] + options[:limit] < response_data['total_record_count']
      options[:offset] += options[:limit]
      response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options))
      
      table_data += response_data['item'].map { |item|
        data = item['item_data']
        unless(policies.has_key?(data['policy']['value']) || data['base_status']['desc'] != "Item in place")
          policies[data['policy']['value']] = nil
          pids_to_check << [data['pid'], data['policy']['value']]
        end
#        data['links'] = ["<a href='/alma/request?mms_id=#{params['mms_id']}&holding_id=#{params['holding_id']}&item_pid=#{data['pid']}' target='_blank'>Request</a>"] unless userid.nil?
        [data['policy']['value'], data['pid'], data['physical_material_type']['desc'], due_date_policy || data['due_date_policy'], data['description'], data['base_status']['desc'], data['barcode'], [], params['mms_id'], params['holding_id']]
      }
    end

    pids_to_check.each{ |pid, policy| 
      options = {:user_id => userid, :item_pid => pid}
      response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_request_options, :get, params.merge(options))
      not_requestable = true
      if response_data.body != '{}'
        not_requestable = response_data['request_option'].select { |option|
          option['type']['value'] == 'HOLD'
        }.empty?
      end
      policies[policy] = "/alma/request/?mms_id=%{mms_id}&holding_id=%{holding_id}&item_pid=%{item_pid}" unless not_requestable
    }

    table_data.each { |item|
      policy = item.shift()
      request_url = (policies[policy] || '') % params.merge({:item_pid => item[0]})
      item[5] << "<a target='_blank' href='#{request_url}'>Request</a>" unless (request_url.empty? || item[3] != 'Item in place')
    }

    render :json => {"data": table_data}
  end

  def request_options
    userid = session['id'].presence || nil
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
            #:option_url => option['request_url'],
            :option_url => "/alma/request?mms_id=#{params['mms_id']}",
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
      .sort { |a,b| cmpRequestOptions(a,b) }

    # TODO: Remove when GES is updated in Alma
    results.reject! { |option| 
      option[:option_name] == 'Send Penn Libraries a question'
    }

    # TODO: Remove when GES is updated in Alma
    results.each { |option|
      case option[:option_name]
      when 'Suggest Fix / Enhance Record'
          option[:option_name] = "Report Error"
      end
    }

    render :json => results
  end

  def request_title?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = {:user_id => userid, :format => 'json'}

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))

    return response_data['request_option'].map { |option| 
      option['type']['value']
    }.member?('HOLD')
  end

  def request_item?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = {:user_id => userid, :format => 'json', :expand => 'due_date_policy'}

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid, :get, params.merge(options))
    item_policy = response_data.dig('item_data', 'policy', 'value').presence
    item_loc = response_data.dig('item_data', 'location', 'value').presence

    # Locations copied from Alma general fulfillment unit loan rules
    loan_locs = ['annb', 'annbnewbk', 'annbstor', 'biom', 'chem', 'chemnewbk',
                   'chemrdrm', 'cjsstk', 'dncirc', 'dent', 'dentnewbks', 'edcomm',
                   'EMPTY', 'engianne', 'engicirc', 'engi', 'enginewbk', 'engiperi',
                   'engirefe', 'engirese', 'engiteac', 'engithes', 'fanewbook', 'fineslid',
                   'fine', 'cjs', 'stor', 'storfine', 'lipp', 'math',
                   'moornewbk', 'moorrefe', 'moorrese', 'moor', 'mathcirc', 'mathnewbk',
                   'muse', 'mscirc', 'museegyp', 'musekolb', 'museover', 'musinwbk',
                   'newbcirc', 'newb', 'pah', 'pahiph', 'presby', 'townanne',
                   'twcirc', 'townnewbk', 'townrefe', 'townrese', 'town', 'townteac',
                   'townthes', 'easiacom', 'easiaover', 'eastasia', 'vanp', 'vpnewbook',
                   'women', 'woody', 'yarn', 'vete', 'vetedisp', 'vetelibr', 'veteover']

    # Item policies copied from Alma general fulfillment unit loan rules
    noloan_item_policies = ['bound jrnl','lawbad','microform','non-circ','reference','slide','special']
    # TODO: what about user groups?

    return !userid.nil? && !item_policy.nil? && !item_loc.nil? && !noloan_item_policies.member?(item_policy) && loan_locs.member?(item_loc)
  end

  def load_request
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    if !params['mms_id'].present?
      render 'catalog/bad_request'
      return
    end
    
    if params['item_pid'].present?
      render 'catalog/bad_request' unless request_item?
    else
      render 'catalog/bad_request' unless request_title?
    end

    return if performed?

    userid = session['id'].presence || 'GUEST'

    # The block below pulls libraries dynamically but the list of valid pickup locations shouldn't
    # change, so I've created a hard-coded list to use below to save an API call and reduce load time.
    #
    #exclude_libs = ['Architectural Archives', 'Area Studies Technical Services', 'EMPTY', 'Education Commons', 'LIBRA', 'ZUnavailable Library']
    #url = "https://api-na.hosted.exlibrisgroup.com/almaws/v1/conf/libraries?apikey=#{ENV['ALMA_API_KEY']}"
    #doc = Nokogiri::XML(open(url))
    #libraries = {}.merge(doc.root.children.map { |lib|
                           #{ lib.xpath('.//name').text => lib.xpath('.//code').text }
                         #}
                         #.reduce(&:merge)
                         #.to_h
                         #.reject { |k,v| exclude_libs.member?(k) }
                        #)

    libraries = { "Annenberg Library" => "AnnenLib",
                  "Biomedical Library" => "BiomLib",
                  "Chemistry Library" => "ChemLib",
                  "Dental Medicine Library" => "DentalLib",
                  "Fisher Fine Arts Library" => "FisherFAL",
                  "Library at the Katz Center" => "KatzLib",
                  "Math/Physics/Astronomy Library" => "MPALib",
                  "Morris Arboretum" => "ArborLib",
                  "Museum Library" => "MuseumLib",
                  "Ormandy Music and Media Center" => "MusicLib",
                  "Pennsylvania Hospital Library" => "PAHospLib",
                  "Van Pelt Library" => "VanPeltLib",
                  "Veterinary Library - New Bolton Center" => "VetNBLib",
                  "Veterinary Library - Penn Campus" => "VetPennLib"
                }

    if params['item_pid'].present?
      api_response = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid, :get, params.merge({:format => 'json'}))
      bib_data, holding_data, item_data = ['bib_data', 'holding_data', 'item_data'].map { |d| api_response[d] }
    else
      api_response = api_instance.request(api.almaws_v1_bibs, :get, params.merge({:format => 'json'}))
      bib_data, holding_data, item_data = api_response.dig('bib', 0), {}, {}
    end

    render 'catalog/request', locals: {:bib_data => bib_data, :holding_data => holding_data, :item_data => item_data, :libraries => libraries} unless performed?
  end

  def create_request
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    if !params['mms_id'].present?
      render 'catalog/bad_request'
      return
    end
    
    if params['item_pid'].present?
      render 'catalog/bad_request' unless request_item?
    else
      render 'catalog/bad_request' unless request_title?
    end

    return if performed?

    userid = session['id'].presence || 'GUEST'

    # For making requests via API, we are required to supply user_id and user_id_type as
    # URL parameters. I spent too much time trying to figure out how to do this following
    # the patterns we use elsewhere for making API requests but ultimately decided to do
    # some string manipulation in the end. The uri_template method below is part of EzWADL
    # and returns a URL base populated with whatever IDs are present in the params hash.
    # After that we add the user_id and user_id_type parameters as well as the api key,
    # and issue an HTTP POST using HTTParty, which is used under the hood for other api calls.

    if params['item_pid'].present? # Do an item level request
      url = api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_requests.uri_template(params)
    else
      url = api.almaws_v1_bibs.mms_id_requests.uri_template(params)
    end

    url += "?user_id=#{userid}&user_id_type=all_unique&apikey=#{ENV['ALMA_API_KEY']}"
    headers = { 'Content-Type' => 'application/json' }
    body = { :request_type => "HOLD",
             :pickup_location_type => "LIBRARY",
             :pickup_location_library => params['pickup_location'],
             :comment => params['comments'] }.to_json

    api_response = HTTParty.post(url, :headers => headers, :body => body)

    render 'catalog/request_created' unless performed?

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
