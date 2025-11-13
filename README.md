# rails-spotify-basecoat (MVP)

Steps to run locally:
1. Copy `.env.example` to `.env` and fill SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET and SPOTIFY_REFRESH_TOKEN.
   - See below for how to obtain a refresh token (one‑time).
2. bundle install
3. foreman start (or rails server)

Visit http://localhost:3000/spotify to see playlists for the configured Spotify account.

## Getting Spotify Credentials

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create a new app.
2. Note the `Client ID` and `Client Secret`.
3. Add `http://localhost:3000/callback` to the Redirect URIs in your app settings.
4. To get a refresh token:
   - Visit: `https://accounts.spotify.com/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http://localhost:3000/callback&scope=playlist-read-private%20user-library-read`
   - Replace `YOUR_CLIENT_ID` with your Client ID.
   - Log in and authorize, you'll get redirected to `http://localhost:3000/callback?code=...`
   - Copy the `code` from the URL.
   - Run: `ruby script/get_refresh_token.rb`
   - Enter your Client ID, Client Secret, and the code.
   - It will print the refresh token (and access token).

Testing with VCR:
- VCR is used for recording HTTP interactions. To record, set your env vars and run the spec; it will create cassettes in spec/vcr_cassettes.
