Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # https://localhost = Capacitor (Android/iOS) WebView sa ugrađenim bundle-om
    origins(
      "http://localhost:3001",
      "http://127.0.0.1:3001",
      "https://localhost",
      "https://hajki.com",
      "https://www.hajki.com"
    )
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end