class LinkResolver
  # @param [String] mms_id
  # @return [String] resolution_url for mmsid
  def self.resolution_url_for(mms_id)
    url = 'https://upenn.alma.exlibrisgroup.com/view/uresolver/01UPENN_INST/openurl?'\
            "&rft.mms_id=#{mms_id}"\
            '&svc_dat=CTO'
    response = HTTParty.get url
    return unless response.success?

    doc = Nokogiri::XML(response.body)
    # TODO: what if >1 resolution_url? may obtain with >1 context_service in response
    doc.search('resolution_url').text
  end
end
