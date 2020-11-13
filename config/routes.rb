Rails.application.routes.draw do
  concern :exportable, Blacklight::Routes::Exportable.new

  # redirects for legacy DLA Franklin links

  get 'index.html' => 'legacy_franklin#redirect_to_root', :format => false
  get 'record.html' => 'legacy_franklin#record', :format => false
  # blacklight_advanced_search has an /advanced route but we never use advanced.html (w/ the format)
  # so this is safe to list here.
  get 'advanced.html' => 'legacy_franklin#redirect_to_root', :format => false
  get '/dla/franklin/record.html' => 'legacy_franklin#record', :format => false
  get '/dla/franklin' => 'legacy_franklin#redirect_to_root', :format => false
  get '/dla/franklin/*any' => 'legacy_franklin#dla_subpaths', :format => false

  root to: "catalog#landing"
  get 'bento/' => 'catalog#bento'

  mount Blacklight::Engine => '/'
  mount BlacklightDynamicSitemap::Engine => '/'


  mount BlacklightAdvancedSearch::Engine => '/'

  #####
  # the reverse routes in blacklight_advanced_search/_facet_limit.html.erb
  # don't work unless these routes exist
  #####
  get 'advanced' => 'advanced#index'
  get 'advanced/facet' => 'advanced#facet'

  get 'collection_news' => 'collection_news#index'

  get 'known_issues' => 'application#known_issues'

  Blacklight::Marc.add_routes(self)
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  # override devise's sessions controller w/ our own
  devise_for :users, controllers: { sessions: 'sessions' }

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  get 'alma/availability' => 'franklin_alma#availability'
  get 'alma/single_availability' => 'franklin_alma#single_availability'
  get 'alma/holding_items' => 'franklin_alma#holding_items'
  get 'alma/holding_details' => 'franklin_alma#holding_details'
  get 'alma/portfolio_details' => 'franklin_alma#portfolio_details'
  get 'alma/request_options' => 'franklin_alma#request_options'
  get 'alma/check_requestable' => 'franklin_alma#check_requestable'

  get 'alma/request' => 'franklin_alma#load_request'
  post 'alma/request' => 'franklin_alma#create_request'

  devise_scope :user do
    get 'alma/social_login_callback' => 'sessions#social_login_callback'
    get 'accounts/login' => 'sessions#sso_login_callback'
  end

  if ENV['ENABLE_DEBUG_URLS'] == 'true'
    get '/headers_debug' => 'application#headers_debug'
    get '/session_debug' => 'application#session_debug'
  end

  BentoSearch::Routes.new(self).draw


  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
