# Placeholder initializer for basecoat — replace with the real initializer if the gem exposes a client class.

if ENV["SPOTIFY_CLIENT_ID"] && ENV["SPOTIFY_CLIENT_SECRET"]
  # If basecoat exposes a client, initialize it here and assign to a constant.
  # Example (adjust if the gem API differs):
  # BasecoatClient = Basecoat::Client.new(client_id: ENV["SPOTIFY_CLIENT_ID"], client_secret: ENV["SPOTIFY_CLIENT_SECRET"])
  BasecoatClient = nil
end
