module PennLib

  # subclass of SolrJsonWriter that sets a higher receive timeout
  # on the underlying http client object
  class FranklinSolrJsonWriter < Traject::SolrJsonWriter

    def initialize(argSettings)
      super(argSettings)
      @http_client.receive_timeout = 600
      @http_client.send_timeout = 1200
    end

    # override of Traject method
    # adding URL params here breaks Traject's ability to append any additional params to the URL
    # breaking Traject's ability to commit
    def solr_update_url_with_query(query_params)
      if query_params
        if @solr_update_url.index '?'
          # we already have query params
          @solr_update_url + '&' + URI.encode_www_form(query_params)
        else
          @solr_update_url + '?' + URI.encode_www_form(query_params)
        end
      else
        @solr_update_url
      end
    end
  end

end
