
# Configuration for bento_search gem

class PennSummonEngine < BentoSearch::SummonEngine

  # send a space char so Summon API doesn't return an error page
  # when 's.q' param is a blank string.
  # TODO: figure out why this hack isn't needed in DLA Franklin.
  def construct_request(args)
    if !args[:query] || args[:query] == ''
      args[:query] = ' '
    end
    super(args)
  end

  def is_user_logged_in?
    # TODO: validate user's token against signing service behind ezproxy
    false
  end

  def search(*arguments)
    if is_user_logged_in?
      arguments.last[:auth] = true
    end
    super(*arguments)
  end
end


BentoSearch.register_engine('summon') do |conf|
  conf.engine     = 'PennSummonEngine'
  conf.access_id  = ENV['SUMMON_ACCESS_ID']
  conf.secret_key = ENV['SUMMON_SECRET_KEY']
  #conf.lang       = 'en'

  conf.fixed_params = {
    # These pre-limit the search to avoid certain content-types, you may or may
    # not want to do.
    #"s.fvf" => ["ContentType,Web Resource,true", "ContentType,Reference,true","ContentType,eBook,true", "ContentType,Book Chapter,true", "ContentType,Newspaper Article,true", "ContentType,Trade Publication Article,true", "ContentType,Journal,true","ContentType,Transcript,true","ContentType,Research Guide,true"],
    # because our entire demo app is behind auth, we can hard-code that
    # all users are authenticated.
    #"s.role" => "authenticated"
    's.ho' => 't',
    's.secure' => 'f',
  }

  # allow ajax load.
  conf.allow_routable_results = true

  conf.highlighting = false

  # ajax loaded results with our wrapper template
  # with total number of hits, link to full results, etc.
  conf.for_display do |display|
    display[:ajax] = { 'wrapper_template' => 'layouts/summon_ajax_results_wrapper' }
    #display.decorator = "RefworksAndOpenUrlLinkDecorator"
  end

end
