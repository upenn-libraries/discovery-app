module MockAlmaApi
  include JsonFixtures

  def stub_holdings_get_success
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings',
      'alma/holdings_get_success.json'
    )
  end

  def stub_alma_user_get_success
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/users/testuser?expand=fees,requests,loans',
      'alma/user_get_success.json'
    )
  end

  def stub_item_get_success
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/3456',
      'alma/item_get_success.json'
    )
  end

  def stub_item_request_post_success
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/3456/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_success.json'
    )
  end

  def stub_item_request_post_failure_empty
    stub_request(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/0000/requests?user_id=testuser&user_id_type=all_unique'
    ).to_return(an_unsuccessful_response_with(''))
  end

  def stub_item_request_post_failure
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/9876/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_failure.json'
    )
  end

  def stub_title_request_post_success
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_success.json'
    )
  end

  def stub_title_request_post_failure
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_failure.json'
    )
  end

  def stub_request_post_failure_no_item
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/1129/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_failure_no_item.json'
    )
  end

  def stub_request_post_failure_already_exists
    stub(
      :post,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/2345/items/1136/requests?user_id=testuser&user_id_type=all_unique',
      'alma/request_post_failure_already_exists.json'
    )
  end

  def stub_turbo_item_get_canary
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/ALL/items?direction=asc&expand=due_date,due_date_policy&limit=1&order_by=description',
      'alma/turbo_item_get_canary.json'
    )
  end

  def stub_turbo_item_get_full
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/holdings/ALL/items?direction=asc&expand=due_date,due_date_policy&limit=100&offset=0&order_by=description',
      'alma/turbo_item_get_full.json'
    )
  end

  def stub_bib_request_options
    stub(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/1234/request-options?user_id=GUEST',
      'alma/bib_request_options.json'
    )
  end

  private

  # @param [Symbol] http_method
  # @param [String, Regexp] uri
  # @param [String] response_fixture filename
  def stub(http_method, uri, response_fixture)
    stub_request(http_method, uri)
      .to_return(
        a_successful_response_with(json_string(response_fixture))
      )
  end

  # @param [String] body
  def a_successful_response_with(body)
    {
      status: 200,
      body: body,
      headers: { 'Content-Type' => 'application/json' }
    }
  end

  def an_unsuccessful_response_with(body)
    {
      status: 500,
      body: body
    }
  end
end
