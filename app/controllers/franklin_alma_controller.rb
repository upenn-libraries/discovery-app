# frozen_string_literal: true

# handle Alma-related actions
class FranklinAlmaController < ApplicationController
  include AlmaOptionOrdering

  PERMITTED_REQUEST_OPTION_CODES = %w[ILLIAD ARES ENHANCED].freeze
  FORCE_UNAVAILABLE_LOCATION_CODES = %w[athNoCirc vpunavail storNoCirc]

  def holding_details
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id, :get, params)

    xml = Nokogiri(response_data.body)
    holding_details = xml.xpath('//datafield[@tag="866"]/subfield[@code="a"]').map(&:text)
    note_details = xml.xpath('//datafield[@tag="852"]/subfield[@code="z"]').map(&:text)
    supplemental_details = xml.xpath('//datafield[@tag="867"]/subfield[@code="a"]').map(&:text)
    index_details = xml.xpath('//datafield[@tag="868"]/subfield[@code="a"]').map(&:text)

    render json: { "holding_details": holding_details, "notes": note_details, "supplement": supplemental_details,
                   "index": index_details }
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
    has_holding_info = holding_info?(bib_data, mmsid)
    # check if portfolio information is present
    has_portfolio_info = portfolio_info?(bib_data, mmsid)

    metadata = check_requestable

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
          link = "<a class='btn btn-default btn-request-option' target='_blank' href='#{link_url}'>#{link_text}</a>"
          public_note_content = collection_response['public_note'].present? ? ['Public Notes: ', collection_response['public_note']] : []
          authentication_note_content = collection_response['authentication_note'].present? ? ['Authentication Notes: ', collection_response['authentication_note']] : []
          notes = ('<span>' + (public_note_content + authentication_note_content).join('<br/>') + '</span>').html_safe
          [
            i,
            link,
            notes,
            '', '', '', '', ''
          ]
        end
        .reject(&:nil?)
    else
      bib_data['availability'][mmsid]['holdings'].each do |holding|
        holding_pickupable = holding['availability'] == 'available'
        pickupable = true if holding_pickupable
        links = []
        if holding['link_to_aeon'] && holding['location_code'] != 'vanpNocirc'
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
                                    elsif holding['location_code'] == 'vanpNocirc' && session['user_group'] != 'Faculty Express'
                                      # we're temporarily disabling all request options for non facex
                                      'Not on shelf'
                                    else
                                      # for non-request-suppressed items and FacEx users, still present the usual link
                                      'Not on shelf; <a class="request-option-link">request below</a>'
                                    end
        elsif holding['availability'] == 'Available' && holding['location_code'] == 'vanpNocirc'
          holding['availability'] = 'Use online access — print restricted'
        elsif holding['availability'] == 'Available' && holding['location_code'].in?(FORCE_UNAVAILABLE_LOCATION_CODES)
          holding['availability'] = 'Unavailable'
        end
      end

      policy = 'Please log in for loan and request information' if userid == 'GUEST'
      table_data = bib_data['availability'][mmsid]['holdings']
                     .select { |h| h['inventory_type'] == 'physical' }
                     .sort { |a, b| compare_holdings(a, b) }
                     .each_with_index
                     .map do |h, i|
                       [
                         i,
                         h['location'],
                         h['availability'],
                         (has_holding_info ? '' : "<span class='load-holding-details' data-mmsid='#{mmsid}' data-holdingid='#{h['holding_id']}'><img src='#{ActionController::Base.helpers.asset_path('ajax-loader.gif')}'/>") + "</span><span id='notes-#{h['holding_id']}'></span>",
                         policy || h['due_date_policy'],
                         h['links'],
                         h['holding_id'],
                         h['item_pid']
                       ]
                     end

      if table_data.empty?
        table_data = bib_data['availability'][mmsid]['holdings']
                     .select { |h| h['inventory_type'] == 'electronic' }
                     .sort { |a, b| compare_services(a, b) }
                     .reject { |p| p['activation_status'] == 'Not Available' }
                     .each_with_index
                     .map do |p, i|
                       link_text = p['collection'] || 'Online'
                       link = "<a target='_blank' href='https://upenn.alma.exlibrisgroup.com/view/uresolver/01UPENN_INST/openurl?Force_direct=true&portfolio_pid=#{p['portfolio_pid']}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com&u.ignore_date_coverage=true' class='btn btn-default'>#{link_text}</a>"
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
      unless policies.key?(data['policy']['value']) ||
             data['base_status']['desc'] != 'Item in place' || userid.nil?
        policies[data['policy']['value']] = nil
        pids_to_check << [data['pid'], data['policy']['value']]
      end
      status = data.dig('location', 'value') == 'vanpNocirc' ? 'Use online access — print restricted' : data['base_status']['desc']
      [
        data['policy']['value'],
        data['pid'],
        data['description'],
        status,
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
        unless policies.key?(data['policy']['value']) || data['base_status']['desc'] != 'Item in place' || userid.nil?
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
    table_data.each do |item|
      policy = item.shift
      request_url = (policies[policy] || '') % params.merge({ item_pid: item[0] })
      unless request_url.empty? || item[2] != 'Item in place'
        item[5] << "<a target='_blank' href='#{request_url}'>PickUp@Penn</a>"
      end
    end

    render json: { "data": table_data }
  end

  # @note this is no longer used for print holdings, only in the datatable
  # widget for e-holdings. for print holdings, see RequestsController
  # @note this code is strongly coupled with Alma's General Electronic
  # Services (Fulfillment) configuration. modification to that configuration
  # can break or otherwise cause bugs in this code.
  def request_options
    userid = session['id'].presence || nil
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    # consider_dlr here tells the API to look at Alma's configured Discovery display logic rules
    # defined in the Alma configuration. it will limit returned options.
    response_data = api_instance.request(
      api.almaws_v1_bibs.mms_id_request_options, :get,
      params.merge({ user_id: userid, consider_dlr: true })
    )

    options = response_data['request_option'].map do |option|
      details = option['general_electronic_service_details'] ||
                option['rs_broker_details'] || {}
      return nil unless option.dig 'request_url'

      case option.dig 'type', 'value'
      when 'GES' # Cataloging error, ScanDeliver, etc.
        {
          option_code: details['code'],
          option_name: details['public_name'],
          option_url: add_bib_rfr_id_params_to(option['request_url'],
                                               params['mms_id']),
          avail_for_physical: details['avail_for_physical'],
          avail_for_electronic: details['avail_for_electronic'],
          highlightable: details['code'] == 'SCANDEL'
        }
      when 'RS_BROKER' # ILL
        {
          option_code: details['code'],
          option_name: details['name'],
          option_url: add_bib_rfr_id_params_to(option['request_url'],
                                               params['mms_id']),
          avail_for_physical: true,
          avail_for_electronic: true,
          highlightable: true
        }
      else
        nil
      end
    end

    render json: options
  end

  def request_title?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = { user_id: userid, format: 'json', consider_dlr: true }

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))

    (response_data['request_option'] || []).map do |option|
      option['type']['value']
    end.member?('HOLD')
  end

  def request_item?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = { user_id: userid, format: 'json' }

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_request_options, :get, params.merge(options))

    (response_data['request_option'] || []).map do |option|
      option['type']['value']
    end.member?('HOLD')
  end

  def load_request
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]

    unless params['mms_id'].present?
      render 'catalog/bad_request'
      return
    end

    if params['item_pid'].present?
      render 'catalog/bad_request' unless request_item?
    else
      render 'catalog/bad_request' unless request_title?
    end

    return if performed?

    # Uncomment these as more libraries open up as delivery options
    libraries = { 'Annenberg Library' => 'AnnenLib',
                  'Athenaeum Library' => 'AthLib',
                  # 'Biotech Commons' => 'BiomLib",
                  # 'Chemistry Library' => 'ChemLib',
                  'Dental Medicine Library' => 'DentalLib',
                  'Fisher Fine Arts Library' => 'FisherFAL',
                  'Library at the Katz Center' => 'KatzLib',
                  # 'Math/Physics/Astronomy Library' => 'MPALib',
                  'Museum Library' => 'MuseumLib',
                  'Ormandy Music and Media Center' => 'MusicLib',
                  'Pennsylvania Hospital Library' => 'PAHospLib',
                  'Van Pelt Library' => 'VanPeltLib',
                  'Veterinary Library - New Bolton Center' => 'VetNBLib',
                  'Veterinary Library - Penn Campus' => 'VetPennLib',
                }

    if params['item_pid'].present?
      api_response = api_instance.request(
        api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid, :get, params.merge({ format: 'json' })
      )
      bib_data, holding_data, item_data = %w[bib_data holding_data item_data].map { |d| api_response[d] }
    else
      api_response = api_instance.request(
        api.almaws_v1_bibs, :get, params.merge({ format: 'json' })
      )
      bib_data, holding_data, item_data = api_response.dig('bib', 0), {}, {}
    end

    render 'catalog/request', locals: {
      bib_data: bib_data, holding_data: holding_data, item_data: item_data, libraries: libraries
    }
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
    body = { request_type: 'HOLD',
             pickup_location_type: 'LIBRARY',
             pickup_location_library: params['pickup_location'],
             comment: params['comments'] }.to_json

    api_response = HTTParty.post(url, headers: headers, body: body)

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
              compare_services(a, b)
            end
          end
        else
          response_data['availability'].keys.each do |mmsid|
            response_data['availability'][mmsid]['holdings'].sort! do |a, b|
              compare_holdings(a, b)
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

  private

  # @return [Class<PennLib::BlacklightAlma::AvailabilityApi>]
  def alma_api_class
    PennLib::BlacklightAlma::AvailabilityApi
  end

  # API key param for appending to Alma API request URLs
  # @return [String]
  def api_key_param
    "apikey=#{ENV['ALMA_API_KEY']}"
  end

  # @param [Object] api_mms_data
  # @param [Object] mmsid
  # @return [TrueClass, FalseClass]
  def holding_info?(api_mms_data, mmsid)
    # check if any holdings have more than one item
    api_mms_data['availability'][mmsid]['holdings'].map(&:keys).reduce([], &:+).member?('holding_info') ||
      api_mms_data['availability'][mmsid]['holdings'].any? { |hld| hld['total_items'].to_i > 1 || hld['availability'] == 'check_holdings' }
  end

  # @param [Object] api_mms_data
  # @param [Object] mmsid
  # @return [TrueClass, FalseClass]
  def portfolio_info?(api_mms_data, mmsid)
    api_mms_data['availability'][mmsid]['holdings'].map(&:keys).reduce([], &:+).member?('portfolio_pid')
  end

  # @return [Hash]
  def check_requestable
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    request_data = api_instance.request(api.almaws_v1_bibs.mms_id_requests, :get, params)
    result = {}

    if request_data.dig('total_record_count') != '0'
      [request_data.dig('user_requests', 'user_request')].flatten.reject(&:nil?).each do |req|
        item_pid = req.dig('item_id').presence
        request_type = req.dig('request_sub_type', '__content__').presence
        result[item_pid] ||= []
        result[item_pid] << request_type
      end
    end

    usergroup = session['user_group'].presence
    mmsid = params[:mms_id]

    result[mmsid] = { facultyexpress: usergroup == 'Faculty Express',
                      group: usergroup }

    result
  end

  # temporary NOTE: only 80% confident (initially) that we want to filter on `pickupable` here
  # this should be set in/returned from `single_availablity` method, and will be `true` if any
  # holding has a raw `holding['availability']` property of `available`
  # @param [Hash] ctx
  # @return [FalseClass, TrueClass]
  def suppress_bbm(ctx)
    return true unless ctx['pickupable'] != false

    return true if ctx['items_nocirc'] == 'all'

    false
  end

  # @return [TrueClass, FalseClass]
  def request_title?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = { user_id: userid, format: 'json', consider_dlr: true }

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_request_options, :get, params.merge(options))

    (response_data['request_option'] || []).map { |option|
      option['type']['value']
    }.member?('HOLD')
  end

  # @return [TrueClass, FalseClass]
  def request_item?
    api_instance = BlacklightAlma::BibsApi.instance
    api = api_instance.ezwadl_api[0]
    userid = session['id'].presence || 'GUEST'
    options = { user_id: userid, format: 'json' }

    response_data = api_instance.request(api.almaws_v1_bibs.mms_id_holdings_holding_id_items_item_pid_request_options, :get, params.merge(options))

    (response_data['request_option'] || []).map { |option|
      option['type']['value']
    }.member?('HOLD')
  end

  # @note this could be added in the Alma configuration
  # @param [String] original_url
  # @param [ActionController::Parameter] mms_id
  # @return [String]
  def add_bib_rfr_id_params_to(original_url, mms_id)
    original_url += original_url.index('?') ? '&' : '?'
    original_url + "bibid=#{mms_id}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com"
  end
end
