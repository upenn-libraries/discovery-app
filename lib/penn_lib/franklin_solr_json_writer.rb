module PennLib

  # subclass of SolrJsonWriter that sets a higher receive timeout
  # on the underlying http client object
  class FranklinSolrJsonWriter < Traject::SolrJsonWriter

    def initialize(argSettings)
      super(argSettings)
      @http_client.receive_timeout = 600
      @http_client.send_timeout = 1200
    end

  end

end
