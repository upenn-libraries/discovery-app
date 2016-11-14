module ApplicationHelper

  def summon_url(query)
    # TODO
    return "http://upenn.summon.serialssolutions.com/search#!/search?q=#{url_encode(query)}"
  end

end
