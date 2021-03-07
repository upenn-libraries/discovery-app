require 'httparty'

module Relais

  def self.authenticate(patron_id)
    url = URI.join(ENV['RELAIS_API_HOST'], 'portal-service/user/authentication')

    body = { :ApiKey => "#{ENV['RELAIS_API_KEY']}",
             :UserGroup => "PATRON",
             :LibrarySymbol => "PENN",
             :PatronId => patron_id
           }

    response = HTTParty.post(url,
      :body => body.to_json,
      :headers => { 'Content-Type' => 'application/json' }
    )

    return response['AuthorizationId']
  end

  def self.addRequest(authz_id, patron_id, title)
    url = URI.join(ENV['RELAIS_API_HOST'], "portal-service/request/add?aid=#{authz_id}")

    body = { "BibliographicInfo": {
               "Title": title
             },
             "RequestFor": {
               "PortalGroup": "PATRON",
               "LibrarySymbol": "PENN",
               "PatronId": patron_id
             }
           }

    response = HTTParty.post(url,
      :body => body.to_json,
      :headers => { 'Content-Type' => 'application/json' }
    )

    return response
  end

  def self.getRequests(authz_id)
    url = URI.join(ENV['RELAIS_API_HOST'], "portal-service/request/query/my?aid=#{authz_id}&type=open")

    response = HTTParty.get(url,
      :headers => { 'Content-Type' => 'application/json' }
    )

    return response
  end

end
