# Overlays run inside OBS and the apps run from other origins; access is
# controlled by tokens, not by the request origin.
Rails.application.config.action_cable.disable_request_forgery_protection = true
