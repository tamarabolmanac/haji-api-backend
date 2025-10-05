Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  
  get "/routes", to: "hike_routes#index"
  get "/routes/:id", to: "hike_routes#show"
  get "/my_routes", to: "hike_routes#my_routes"
  post "/new_route", to: "hike_routes#create"
  delete "/routes/:id", to: "hike_routes#destroy"

  # Authentication routes
  post "/auth/register", to: "auth#register"
  post "/auth/login", to: "auth#login"
  
  # User routes
  get "/user_data", to: "users#user_data"
  post "/add_point", to: "points#create"
  
  # Route tracking
  post "/routes/track_point", to: "hike_routes#track_point"
  

  get "/users/confirm/:token", to: "users#confirm"
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
