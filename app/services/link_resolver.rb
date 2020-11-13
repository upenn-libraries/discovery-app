class LinkResolver
  # @param [String] mms_id
  # @return [String] resolution_url for mmsid
  def self.resolution_url_for(mms_id)
    url = 'https://upenn.alma.exlibrisgroup.com/view/uresolver/01UPENN_INST/openurl?'\
            '&u.ignore_date_coverage=true'\
            "&rft.mms_id=#{mms_id}"\
            '&rfr_id=info:sid/primo.exlibrisgroup.com'\
            '&svc_dat=CTO'
    response = HTTParty.get url
    return unless response.success?

    doc = Nokogiri::XML(response.body)
    doc.search('resolution_url').text
  end
end
