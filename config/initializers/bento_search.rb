
# Configuration for bento_search gem

BentoSearch.register_engine('summon') do |conf|
  conf.engine     = 'PennLib::SummonEngine'
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
    display[:no_results_partial] = 'layouts/summon_zero_results'
    #display.decorator = "RefworksAndOpenUrlLinkDecorator"
  end

  conf.check_auth = lambda do |param_hash, request|
    summon_auth = request.headers['x-summon-role-auth']
    if summon_auth.blank?
      param_hash[:auth] = false
    else
      #TODO actually verify the header value
      param_hash[:auth] = true
    end
    param_hash
  end
end

BentoSearch.register_engine('google_site_search') do |conf|
  conf.engine = 'BentoSearch::GoogleSiteSearchEngine'
  conf.api_key = ENV['GOOGLE_CSE_API_KEY']
  conf.cx = ENV['GOOGLE_CSE_CX']
  # allow ajax load.
  conf.allow_routable_results = true
  conf.for_display do |display|
    display[:ajax] = { 'wrapper_template' => 'layouts/google_site_search_ajax_results_wrapper' }
    display[:no_results_partial] = 'layouts/zero_google_results'
    #display[:no_results_partial] = 'layouts/google_zero_results'
  end
end

BentoSearch.register_engine('colenda') do |conf|
  conf.engine     = 'BentoSearch::ColendaEngine'
  conf.allow_routable_results = true
  conf.for_display do |display|
    display[:ajax] = { 'wrapper_template' => 'layouts/colenda_ajax_results_wrapper' }
    display[:no_results_partial] = 'layouts/hide_colenda_zero_results'
  end
end

# BentoSearch.register_engine('catalog') do |conf|
#   conf.engine     = 'BentoSearch::CatalogEngine'
#   conf.allow_routable_results = true
#   conf.for_display do |display|
#     display[:ajax] = { 'wrapper_template' => 'layouts/catalog_ajax_results_wrapper' }
#     display[:no_results_partial] = 'catalog/zero_results_bento'
#   end
# end

BentoSearch.register_engine('databases') do |conf|
  conf.engine     = 'BentoSearch::DatabasesEngine'
  conf.allow_routable_results = true
  conf.for_display do |display|
    display[:ajax] = { 'wrapper_template' => 'layouts/databases_ajax_results_wrapper' }
    display[:no_results_partial] = 'layouts/hide_databases_zero_results'
    #display[:no_results_partial] = 'layouts/databases_zero_results'
  end
end

BentoSearch::SearchController.before_action do |controller|
  check_auth = controller.engine.configuration.check_auth
  if check_auth != nil
    engine_args = controller.safe_search_args(controller.engine, controller.params)
    engine_args = check_auth.call(engine_args, controller.request)
    controller.engine_args = engine_args
  end
end
