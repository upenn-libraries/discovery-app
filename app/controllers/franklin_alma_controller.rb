require 'json'

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
    collection_a = service_a['collection'] || ''
    interface_a = service_a['interface_name'] || ''
    collection_b = service_b['collection'] || ''
    interface_b = service_b['interface_name'] || ''

    score_a = -[@@toplist['collection'][collection_a] || 0, @@toplist['interface'][interface_a] || 0].max
    score_a = [@@bottomlist['collection'][collection_a] || 0, @@bottomlist['interface'][interface_a] || 0].max if score_a == 0

    score_b = -[@@toplist['collection'][collection_b] || 0, @@toplist['interface'][interface_b] || 0].max
    score_b = [@@bottomlist['collection'][collection_b] || 0, @@bottomlist['interface'][interface_b] || 0].max if score_b == 0

    return (score_a == score_b ? collection_a <=> collection_b : score_a <=> score_b)
  end

  def cmpHoldingLocations(holding_a, holding_b)
    lib_a = holding_a['library_code'] || ''
    lib_b = holding_b['library_code'] || ''

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

    render :json => { "holding_details": holding_details.join("<br/>").html_safe, "notes": (note_details + supplemental_details + index_details).join("<br/>").html_safe }

  end

  # Return JSON of portfolio details (public & authentication notes only)
  # Also returns received coverage value
  # @todo wrap API calls
  # Params can include:
  #  - portfolio_pid
  #  - collection_id
  #  - coverage
  #  - public_note
  # Data is queried for in this order:
  #  1. Portfolio API
  #  2. Service API
  #  3. Collection API
  def portfolio_details
    alma_api_base_path = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1'
    request_headers = { 'Accept' => 'application/json' }

    # TODO: params can have a public_note value, not to mention coverage. where are those values coming from?
    # the Availability API call made earlier? "we also get this from availability API. Opportunity for improvement?"

    # Get the right Service ID from the Bibs API
    bib_portfolio_url = "#{alma_api_base_path}/bibs/#{params[:mms_id]}/portfolios/#{params[:portfolio_pid]}?#{api_key_param}"
    bib_portfolio_response = HTTParty.get(bib_portfolio_url, headers: request_headers)
    service_id = bib_portfolio_response.dig 'electronic_collection', 'service', 'value'

    public_note = nil # TODO: determine if the value from params should take precedence over any API call below
    authentication_note = nil

    # The portfolio is the most trustworthy source for details
    if service_id && params[:collection_id] && params[:portfolio_pid]
      portfolio_url = "#{alma_api_base_path}/electronic/e-collections/#{params[:collection_id]}/e-services/#{service_id}/portfolios/#{params[:portfolio_pid]}?#{api_key_param}"
      portfolio_response = HTTParty.get(portfolio_url, headers: request_headers)
      public_note ||= portfolio_response['public_note'].presence
      authentication_note ||= portfolio_response['authentication_note'].presence
    end

    # Next try the Service
    service_url = bib_portfolio_response.dig 'electronic_collection', 'service', 'link'
    if service_url && (public_note.nil? || authentication_note.nil?)
      service_response = HTTParty.get(service_url + "?#{api_key_param}", headers: request_headers)
      public_note ||= service_response['public_note'].presence
      authentication_note ||= service_response['authentication_note'].presence
    end

    # Finally check the Collection (not set in standalone case)
    if params[:collection_id].present? && (public_note.nil? || authentication_note.nil?)
      collection_url = "#{alma_api_base_path}/electronic/e-collections/#{params[:collection_id]}?#{api_key_param}"
      collection_response = HTTParty.get(collection_url, headers: request_headers)
      public_note ||= collection_response['public_note'].presence
      authentication_note ||= collection_response['authentication_note'].presence
    end

    render json: { portfolio_details: params[:coverage].squish,
                   public_note: public_note, authentication_note: authentication_note }
  end

  def has_holding_info?(api_mms_data, mmsid)
    # check if any holdings have more than one item
    api_mms_data['availability'][mmsid]['holdings'].map(&:keys).reduce([], &:+).member?('holding_info') ||
      api_mms_data['availability'][mmsid]['holdings'].any? { |hld| hld['total_items'].to_i > 1 || hld['availability'] == 'check_holdings' }
  end

  def has_portfolio_info?(api_mms_data, mmsid)
    api_mms_data['availability'][mmsid]['holdings'].map(&:keys).reduce([], &:+).member?('portfolio_pid')
  end

  def single_availability
    availability_status = { 'available' => 'Available',
                            'check_holdings' => 'Requestable' }

    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    mmsid = params[:mms_id]
    userid = session['id'].presence || 'GUEST'
    bibapi = alma_api_class.new
    bib_data = bibapi.get_availability([mmsid])
    holding_map = {}
    pickupable = false
    inventory_type = ''

    # check if any holdings have more than one item
    has_holding_info = has_holding_info?(bib_data, mmsid)
    # check if portfolio information is present
    has_portfolio_info = has_portfolio_info?(bib_data, mmsid)

    metadata = check_requestable(has_holding_info)

    # Load holding information for monographs. Monographs do not have
    # a 'holding_info' value.
    unless has_holding_info
      holding_data = api_instance.request(
        api.almaws_v1_bibs.mms_id_holdings_holding_id_items,
        :get,
        mms_id: mmsid, holding_id: 'ALL', expand: 'due_date_policy', user_id: userid
      )

      [holding_data['items']['item']].flatten.reject(&:nil?).each do |item|
        holding_id = item['holding_data']['holding_id']
        item_pid = item['item_data']['pid']
        due_date_policy = item['item_data']['due_date_policy']
        holding_map[holding_id] ||= {}
        holding_map[holding_id][:item_pid] = item_pid
        holding_map[holding_id][:due_date_policy] = due_date_policy
      end
    end

    # Check if URL for bib is on collection record
    if bib_data['availability'][mmsid]['holdings'].empty?
      inventory_type = 'electronic'
      bib_collection_response = api_instance.request(
        api.almaws_v1_bibs.mms_id_e_collections, :get, mms_id: mmsid
      )
      table_data =
        [bib_collection_response.dig('electronic_collections', 'electronic_collection')]
        .flatten.reject(&:nil?).each_with_index
        .map do |c, i|
          url = c.dig('link')
          next if url.nil?

          collection_response = HTTParty.get(
            url + "?apikey=#{ENV['ALMA_API_KEY']}",
            headers: { 'Accept' => 'application/json' }
          )
          link_url = collection_response['url_override'].presence || collection_response['url']
          link_text = collection_response['public_name_override'].presence || collection_response['public_name']
          link = "<a target='_blank' href='#{link_url}'>#{link_text}</a>"
          public_note_content = collection_response['public_note'].present? ? ['Public Notes: ', collection_response['public_note']] : []
          authentication_note_content = collection_response['authentication_note'].present? ? ['Authentication Notes: ', collection_response['authentication_note']] : []
          notes = ('<span>' + (public_note_content + authentication_note_content).join("<br/>") + '</span>').html_safe
          [
            i,
            link,
            notes,
            '', '', '', '', ''
          ]
        end
        .reject(&:nil?)
    else
      ctx = JSON.parse(params[:request_context])
      bib_data['availability'][mmsid]['holdings'].each do |holding|
        holding_pickupable = holding['availability'] == 'available'
        pickupable = true if holding_pickupable
        links = []
        if holding['link_to_aeon'] && !(ctx['hathi_etas'] && ctx['monograph'])
          links << "<a href='/redir/aeon?bibid=#{holding['mmsid']}&hldid=#{holding['holding_id']}'' target='_blank'>Request to view in reading room</a>"
        end
        holding['availability'] = availability_status[holding['availability']] || 'Requestable'
        if has_holding_info
          inventory_type = 'physical'
          holding['location'] =
            %Q[<a href="javascript:loadItems('#{mmsid}', '#{holding['holding_id'].presence || 'ALL'}', '#{holding['location_code']}', '#{holding_pickupable}')">#{holding['location']} &gt;</a><br /><span class="call-number">#{holding['call_number']}</span>]
          holding['availability'] =
            "<span class='load-holding-details' data-mmsid='#{mmsid}' data-holdingid='#{holding['holding_id']}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/></span>"
        elsif has_portfolio_info
          inventory_type = 'electronic'
          holding['availability'] =
            "<span class='load-portfolio-details' data-mmsid='#{mmsid}' data-portfoliopid='#{holding['portfolio_pid']}' data-collectionid='#{holding['collection_id']}' data-coverage='#{holding['coverage_statement']}' data-publicnote='#{holding['public_note']}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/></span>"
        else
          inventory_type = 'physical'
          holding['location'] = %Q[#{holding['location']}<br /><span class="call-number">#{holding['call_number']}</span>]
          holding['item_pid'] = holding_map.dig(holding['holding_id'], :item_pid)
          holding['due_date_policy'] = holding_map.dig(holding['holding_id'], :due_date_policy)
        end
        holding['links'] = links
        if holding['availability'] == 'Requestable'
          holding['availability'] = if userid == 'GUEST'
                                      'Log in &amp; request below'
                                    elsif suppress_pickup_at_penn(ctx) && session['user_group'] != 'Faculty Express'
                                      # we're temporarily disabling all request options for non facex
                                      'Not on shelf'
                                    else
                                      # for non-request-suppressed items and FacEx users, still present the usual link
                                      'Not on shelf; <a class="request-option-link">request below</a>'
                                    end
        elsif holding['availability'] == 'Available' && suppress_pickup_at_penn(ctx)
          holding['availability'] = 'Restricted (COVID-19)'
        end
      end

      policy = 'Please log in for loan and request information' if userid == 'GUEST'
      table_data = bib_data['availability'][mmsid]['holdings']
                     .select { |h| h['inventory_type'] == 'physical' }
                     .sort { |a, b| cmpHoldingLocations(a, b) }
                     .each_with_index
                     .map do |h, i|
                       [
                         i,
                         h['location'],
                         h['availability'],
                         (has_holding_info ? "" : "<span class='load-holding-details' data-mmsid='#{mmsid}' data-holdingid='#{h['holding_id']}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/>") + "</span><span id='notes-#{h['holding_id']}'></span>",
                         policy || h['due_date_policy'],
                         h['links'],
                         h['holding_id'],
                         h['item_pid']
                       ]
                     end

      if table_data.empty?
        table_data = bib_data['availability'][mmsid]['holdings']
                     .select { |h| h['inventory_type'] == 'electronic' }
                     .sort { |a, b| cmpOnlineServices(a, b) }
                     .reject { |p| p['activation_status'] == 'Not Available' }
                     .each_with_index
                     .map do |p, i|
                       link_text = p['collection'] || 'Online'
                       link = "<a target='_blank' href='https://upenn.alma.exlibrisgroup.com/view/uresolver/01UPENN_INST/openurl?Force_direct=true&portfolio_pid=#{p['portfolio_pid']}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com&u.ignore_date_coverage=true'>#{link_text}</a>"
                       [
                         i,
                         link,
                         p['availability'],
                         "<span id='notes-#{p['portfolio_pid']}'></span>",
                         '', '', '', ''
                       ]
                     end
      end
    end
    metadata[mmsid][:inventory_type] = inventory_type
    metadata[mmsid][:pickupable] = pickupable
    render json: { "metadata": metadata, "data": table_data }
  end

  def check_requestable(has_holding_info = false)
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    request_data = api_instance.request(api.almaws_v1_bibs.mms_id_requests, :get, params)
    result = {}
    requestable = false

    if request_data.dig('total_record_count') != '0'
      [request_data.dig('user_requests', 'user_request')].flatten.reject(&:nil?).each do |req|
        item_pid = req.dig('item_id').presence
        request_type = req.dig('request_sub_type', '__content__').presence
        result[item_pid] ||= []
        result[item_pid] << request_type
      end
    end

    userid = session['id'].presence
    usergroup = session['user_group'].presence
    mmsid = params[:mms_id]

    result[mmsid] = {:facultyexpress => usergroup == 'Faculty Express', :group => usergroup}

    return result

  end

  def holding_items
    userid = session['id'].presence || nil
    due_date_policy = 'Please log in for loan and request information' if userid.nil?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    options = { expand: 'due_date_policy', offset: 0, limit: 100,
                user_id: userid, order_by: 'description' }
    response_data = api_instance.request(
      api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options)
    )
    unless response_data.key?('item')
      render json: { "data": [] }
      return
    end

    policies = {}
    pids_to_check = []

    # table_data here is used to compose the columns in the availability DataTable
    table_data = response_data['item'].map do |item|
      data = item['item_data']
      unless policies.has_key?(data['policy']['value']) ||
             data['base_status']['desc'] != "Item in place" || userid.nil?
        policies[data['policy']['value']] = nil
        pids_to_check << [data['pid'], data['policy']['value']]
      end
      [
        data['policy']['value'],
        data['pid'],
        data['description'],
        data['base_status']['desc'],
        data['barcode'],
        due_date_policy || data['due_date_policy'],
        [],
        params['mms_id'],
        params['holding_id']
      ]
    end

    # add some more rows to table_data (duplicates above)
    while options[:offset] + options[:limit] < response_data['total_record_count']
      options[:offset] += options[:limit]
      response_data = api_instance.request(
        api.almaws_v1_bibs.mms_id_holdings_holding_id_items, :get, params.merge(options)
      )
      table_data += response_data['item'].map do |item|
        data = item['item_data']
        unless policies.has_key?(data['policy']['value']) || data['base_status']['desc'] != "Item in place" || userid.nil?
          policies[data['policy']['value']] = nil
          pids_to_check << [data['pid'], data['policy']['value']]
        end
        [
          data['policy']['value'],
          data['pid'],
          data['description'],
          data['base_status']['desc'],
          data['barcode'],
          due_date_policy || data['due_date_policy'],
          [],
          params['mms_id'],
          params['holding_id']
        ]
      end
    end

    pids_to_check.each do |pid, policy|
      options = { user_id: userid, item_pid: pid }
      response_data = api_instance.request(
        api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_request_options, :get, params.merge(options)
      )
      not_requestable = true
      if response_data.body != '{}'
        not_requestable = response_data['request_option'].select do |option|
          option['type']['value'] == 'HOLD'
        end.empty?
      end
      unless not_requestable
        policies[policy] = '/alma/request/?mms_id=%{mms_id}&holding_id=%{holding_id}&item_pid=%{item_pid}'
      end
    end
    suppress = suppress_pickup_at_penn(JSON.parse(params['request_context']))
    table_data.each do |item|
      policy = item.shift
      request_url = (policies[policy] || '') % params.merge({ item_pid: item[0] })
      # TODO: when libraries reopen: remove conditional, Pickup@Penn=>Request
      unless request_url.empty? || item[2] != 'Item in place'
        item[5] << (suppress ? '' : "<a target='_blank' href='#{request_url}'>PickUp@Penn</a>")
      end
    end

    render json: { "data": table_data }
  end

  def suppress_pickup_at_penn(ctx)
    return false unless ctx['monograph']
    return true unless ctx['pickupable'] != false
    return true if ctx['hathi_etas'] #|| ctx['hathi_pd']

    false
  end

  def request_options
    userid = session['id'].presence || nil
    usergroup = session['user_group'].presence
    ctx = JSON.parse(params['request_context'])
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    options = { user_id: userid, consider_dlr: true }
    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))
    results = response_data['request_option'].map do |option|
      request_url = option['request_url']
      details = option['general_electronic_service_details'] || option['rs_broker_details'] || {}
      if request_url.nil?
        nil
      else
        case option['type']['value']
        when 'HOLD'
          # TODO: when libraries reopen: remove conditional, Pickup@Penn=>Request
          unless suppress_pickup_at_penn(ctx)
            {
              option_name: 'PickUp@Penn',
              # option_url: option['request_url'],
              option_url: "/alma/request?mms_id=#{params['mms_id']}",
              avail_for_physical: true,
              avail_for_electronic: true,
              highlightable: true
            }
          end
        when 'GES'
          option_url = option['request_url']
          option_url += if option_url.index('?')
                          '&'
                        else
                          '?'
                        end
          {
            option_name: details['public_name'],
            # Remove appended mmsid when SF case #00584311 is resolved
            option_url: option_url + "bibid=#{params['mms_id']}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com",
            avail_for_physical: details['avail_for_physical'],
            avail_for_electronic: details['avail_for_electronic'],
            highlightable: ['SCANDEL'].member?(details['code'])
          }
        when 'RS_BROKER'
          option_url = option['request_url']
          option_url += if option_url.index('?')
                          '&'
                        else
                          '?'
                        end
          # explicitly set requesttype to book if we are working with a monograph
          # this will ensure the ILL "Book" request form is loaded
          option_url += 'requesttype=book&' if ctx['monograph']
          {
            option_name: details['name'],
            # Remove appended mmsid when SF case #00584311 is resolved
            option_url: option_url + "bibid=#{params['mms_id']}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com",
            avail_for_physical: true,
            avail_for_electronic: true,
            highlightable: true
          }
        else
          nil
        end
      end
    end

    # .uniq required due to request options API bug returning duplicate options
    results = results.compact.uniq.sort { |a, b| cmpRequestOptions(a, b) }

    # TODO: Remove when GES is updated in Alma & request option API is fixed (again)
    results.reject! do |option|
      ['Send Penn Libraries a question', 'Books By Mail'].member?(option[:option_name]) ||
        (option[:option_name] == 'FacultyEXPRESS' && usergroup != 'Faculty Express')
    end

    # TODO: Remove when GES is updated in Alma
    results.each do |option|
      if option[:option_name] == 'Suggest Fix / Enhance Record'
        option[:option_name] = 'Report Cataloging Error'
      end
    end

    # suppress for bbm is same as for Pickup@Penn
    if ['Associate', 'Athenaeum Staff', 'Faculty', 'Faculty Express',
        'Faculty Spouse', 'Grad Student', 'Library Staff', 'Medical Center Staff',
        'Retired Library Staff', 'Staff', 'Undergraduate Student']
       .member?(session['user_group']) && !suppress_pickup_at_penn(ctx)
      results.append(
        {
          option_name: 'Books By Mail',
          option_url: "https://franklin.library.upenn.edu/redir/booksbymail?bibid=#{params['mms_id']}",
          avail_for_physical: true,
          avail_for_electronic: false,
          highlightable: true
        }
      )
    end

    render json: results
  end

  def request_title?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = {:user_id => userid, :format => 'json', :consider_dlr => true}

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))

    return (response_data['request_option'] || []).map { |option|
      option['type']['value']
    }.member?('HOLD')
  end

  def request_item?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = {:user_id => userid, :format => 'json'}

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_request_options, :get, params.merge(options))

    return (response_data['request_option'] || []).map { |option|
      option['type']['value']
    }.member?('HOLD')
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

    # Uncomment these as more libraries open up as delivery options
    libraries = { #"Annenberg Library" => "AnnenLib",
                  #"Athenaeum Library" => "AthLib",
                  #"Biomedical Library" => "BiomLib",
                  #"Chemistry Library" => "ChemLib",
                  #"Dental Medicine Library" => "DentalLib",
                  #"Fisher Fine Arts Library" => "FisherFAL",
                  #"Library at the Katz Center" => "KatzLib",
                  #"Math/Physics/Astronomy Library" => "MPALib",
                  #"Museum Library" => "MuseumLib",
                  #"Ormandy Music and Media Center" => "MusicLib",
                  #"Pennsylvania Hospital Library" => "PAHospLib",
                  "Van Pelt Library" => "VanPeltLib"
                  #"Veterinary Library - New Bolton Center" => "VetNBLib",
                  #"Veterinary Library - Penn Campus" => "VetPennLib"
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
      api = alma_api_class.new
      id_list = params[:id_list].split(',')
      response_data = api.get_availability(id_list)

      if response_data.include?('availability')
        if response_data.dig(
          'availability',
          id_list.first, 'holdings', 0, 'inventory_type'
        ) == 'electronic'
          response_data['availability'].keys.each do |mmsid|
            response_data['availability'][mmsid]['holdings'].sort! do |a, b|
              cmpOnlineServices(a, b)
            end
          end
        else
          response_data['availability'].keys.each do |mmsid|
            response_data['availability'][mmsid]['holdings'].sort! do |a, b|
              cmpHoldingLocations(a, b)
            end
          end
        end
      end
    else
      response_data = {
        'error' => 'No id_list parameter'
      }
    end

    respond_to do |format|
      format.xml  { render xml: response_data }
      format.json { render json: response_data }
    end
  end

  # API key param for appending to Alma API request URLs
  # @return [String]
  def api_key_param
    "apikey=#{ENV['ALMA_API_KEY']}"
  end
end
