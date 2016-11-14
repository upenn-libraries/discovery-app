
# Configuration for bento_search gem

BentoSearch.register_engine('summon') do |conf|
  conf.engine     = 'BentoSearch::SummonEngine'
  conf.access_id  = ENV['SUMMON_ACCESS_ID']
  conf.secret_key = ENV['SUMMON_SECRET_KEY']
  conf.lang       = 'en'

  conf.fixed_params = {
    # These pre-limit the search to avoid certain content-types, you may or may
    # not want to do.
    #"s.fvf" => ["ContentType,Web Resource,true", "ContentType,Reference,true","ContentType,eBook,true", "ContentType,Book Chapter,true", "ContentType,Newspaper Article,true", "ContentType,Trade Publication Article,true", "ContentType,Journal,true","ContentType,Transcript,true","ContentType,Research Guide,true"],
    # because our entire demo app is behind auth, we can hard-code that
    # all users are authenticated.
    #"s.role" => "authenticated"
  }

  # allow ajax load.
  conf.allow_routable_results = true

  # ajax loaded results with our wrapper template
  # with total number of hits, link to full results, etc.
  conf.for_display do |display|
    display[:ajax] = { 'wrapper_template' => 'layouts/summon_ajax_results_wrapper' }
    #display.decorator = "RefworksAndOpenUrlLinkDecorator"
  end

end
