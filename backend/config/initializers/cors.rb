# The SvelteKit frontend, the Capacitor Android app and OBS browser sources
# all call this API from other origins. Auth is a bearer token, not a cookie,
# so credentials are not needed and any origin is allowed by default.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "*").split(","))
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization]
  end
end
