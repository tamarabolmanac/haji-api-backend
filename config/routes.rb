Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  
  get "/routes", to: "hike_routes#index"
  get "/routes/:id", to: "hike_routes#show"
  get "/my_routes", to: "hike_routes#my_routes"
  get "/nearby", to: "hike_routes#nearby"
  post "/nearby/overpass", to: "hike_routes#nearby_overpass"
  post "/new_route", to: "hike_routes#create"
  put "/routes/:id", to: "hike_routes#update"
  delete "/routes/:id", to: "hike_routes#destroy"
  post "/routes/:id/like", to: "hike_routes#like"
  delete "/routes/:id/like", to: "hike_routes#unlike"

  # Authentication routes
  post "/auth/register", to: "auth#register"
  post "/auth/login", to: "auth#login"
  
  # User routes (show must be before /users/confirm/:token in matching - confirm is under confirm action)
  get "/users/confirm/:token", to: "users#confirm"
  get "/users/:id", to: "users#show", constraints: { id: /\d+/ }
  get "/users", to: "users#index"
  get "/user_data", to: "users#user_data"
  put "/user", to: "users#update"
  post "/add_point", to: "points#create"
  post "/users/:id/follow", to: "users#follow"
  delete "/users/:id/unfollow", to: "users#unfollow"
  
  # Route tracking
  post "/routes/start_new", to: "hike_routes#start_new"
  post "/routes/track_point", to: "hike_routes#track_point"
  post "/routes/track_points_bulk", to: "hike_routes#track_points_bulk"
  post "/routes/:id/start_tracking", to: "hike_routes#start_tracking"
  post "/routes/:id/finalize", to: "hike_routes#finalize"
  

  post "/forgot-password", to: "users#forgot_password"
  post "/reset-password", to: "users#reset_password"
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path ("/") — return 404 without RoutingError (API nema HTML homepage)
  get "/", to: "application#not_found"

  get "/online_users", to: "users#online"

  # Google Authentication
  post '/auth/google', to: 'sessions#google_auth'

  # ActionCable
  mount ActionCable.server => '/cable'

  # Catch-all: bot probes (WordPress, xmlrpc, etc.) and unknown paths return 404 without raising RoutingError
  match "*path", to: "application#not_found", via: :all
end
