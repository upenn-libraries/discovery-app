Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  concern :exportable, Blacklight::Routes::Exportable.new

  root to: "catalog#landing"
  get 'bento/' => 'catalog#bento'

  mount Blacklight::Engine => '/'

  mount BlacklightAdvancedSearch::Engine => '/'

  #####
  # the reverse routes in blacklight_advanced_search/_facet_limit.html.erb
  # don't work unless these routes exist
  #####
  get 'advanced' => 'advanced#index'
  get 'advanced/facet' => 'advanced#facet'

  get 'nopennkey' => 'catalog#nopennkey'

  get 'collection_news' => 'collection_news#index'

  get 'known_issues' => 'application#known_issues'

  Blacklight::Marc.add_routes(self)
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable
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
