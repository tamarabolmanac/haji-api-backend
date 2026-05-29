Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # https://localhost = Capacitor (Android/iOS) WebView sa ugrađenim bundle-om
    origins(
      "http://localhost:3001",
      "http://127.0.0.1:3001",
      "https://localhost",
      "http://localhost",          # Capacitor Android WebView (starije verzije)
      "capacitor://localhost",     # Capacitor Android/iOS native bundle
      "ionic://localhost",         # Ionic kompatibilnost
      "https://hajki.com",
      "https://www.hajki.com"
    )
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end