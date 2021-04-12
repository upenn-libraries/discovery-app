# frozen_string_literal: true

module MockIlliadApi
  include JsonFixtures

  def stub_transaction_post_success
    stub_request(:post, "#{ENV['ILLIAD_API_BASE_URI']}/transaction")
      .with(
        body: 'Username=testuser&ProcessType=Borrowing&LoanAuthor=Resnik%2C%20Michael%20D.&LoanTitle=Mathematics%20as%20a%20science%20of%20patterns%20%2F&LoanPublisher=Oxford%20University%20Press&LoanPlace=Oxford%20%3A%20New%20York%20%3A&LoanDate=1997.&LoanEdition=&ISSN=0198236085%20%28hb%29&ESPNumber=&Notes=&CitedIn=&ItemInfo1=booksbymail',
        headers: default_headers
      ).to_return(
        status: 200,
        body: json_string('illiad/transaction_post_success.json'),
        headers: {}
      )
  end

  def stub_transaction_post_failure
    stub_request(:post, "#{ENV['ILLIAD_API_BASE_URI']}/transaction")
      .with(
        body: 'invalid-body',
        headers: default_headers
      ).to_return(
        status: 400,
        body: json_string('illiad/transaction_post_failure.json'),
        headers: {}
      )
  end

  def stub_illiad_user_get_success
    stub_request(:get, "#{ENV['ILLIAD_API_BASE_URI']}/users/testuser")
      .with(
        headers: default_headers
      )
      .to_return(
        status: 200,
        body: json_string('illiad/user_success_response.json'),
        headers: {}
      )
  end

  def stub_illiad_user_get_failure
    stub_request(:get, "#{ENV['ILLIAD_API_BASE_URI']}/users/irrealuser")
      .with(
        headers: default_headers
      )
      .to_return(
        status: 404,
        body: json_string('illiad/user_get_failure.json'),
        headers: {}
      )
  end

  def stub_illiad_user_post_success
    stub_request(:post, "#{ENV['ILLIAD_API_BASE_URI']}/users")
      .with(
        body: 'Username=testuser&LastName=User&FirstName=Test&EMailAddress=testuser%40upenn.edu&NVTGC=VPL',
        headers: default_headers
      ).to_return(
        status: 200,
        body: json_string('illiad/user_success_response.json'),
        headers: {}
      )
  end

  def stub_illiad_user_post_failure
    stub_request(:post, "#{ENV['ILLIAD_API_BASE_URI']}/users")
      .with(
        body: '{ "Username":"value" }',
        headers: default_headers
      ).to_return(
        status: 400,
        body: '',
        headers: {}
    )
  end

  private

  def default_headers
    { 'Accept' => 'application/json; version=1',
      'Apikey' => ENV['ILLIAD_API_KEY'] }
  end
end
