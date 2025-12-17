# Spotify to Tidal Playlist Sync

A Rails application to sync playlists from Spotify to Tidal using official APIs.

## Features
- Import Spotify playlists
- Automatic track matching between Spotify and Tidal
- Background job processing for large playlists
- User authentication with both services
- Rate limiting and retry logic for API calls

## Setup

### Prerequisites
- Ruby 3.x
- Rails 8.1+
- Spotify Developer Account
- Tidal Developer Account

### Installation

1. Clone the repository
2. Copy `.env.example` to `.env` and fill in your credentials:
   - `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` from Spotify
   - `TIDAL_CLIENT_ID` and `TIDAL_CLIENT_SECRET` from Tidal
   - See sections below for obtaining these credentials
3. Install dependencies:
   ```bash
   bundle install
   ```
4. Run database migrations:
   ```bash
   rails db:migrate
   ```
5. Start the server:
   ```bash
   foreman start
   ```

Visit http://localhost:3000 to start using the app.

## Getting API Credentials

### Spotify API Setup

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Note the `Client ID` and `Client Secret`
4. Add `http://localhost:3000/callback` to the Redirect URIs
5. To get a refresh token:
   - Visit: `https://accounts.spotify.com/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http://localhost:3000/callback&scope=playlist-read-private%20user-library-read`
   - Replace `YOUR_CLIENT_ID` with your Client ID
   - Log in and authorize, you'll be redirected to `http://localhost:3000/callback?code=...`
   - Copy the `code` from the URL
   - Run: `ruby script/get_refresh_token.rb`
   - Enter your Client ID, Client Secret, and the code
   - The script will print your refresh token

### Tidal API Setup

1. Go to [Tidal Developer Portal](https://developer.tidal.com/)
2. Create a new application
3. Note the `Client ID` and `Client Secret`
4. Add `http://localhost:3000/auth/tidal/callback` to your app's redirect URIs
5. Users will authenticate via the app's OAuth flow (no manual token needed)

## Usage

1. Start the application and create an account
2. Connect your Spotify account (enter user ID to search playlists)
3. Connect your Tidal account (via OAuth flow in the app)
4. Import playlists from Spotify
5. Sync them to Tidal with automatic track matching

## API Information

This application uses:
- **Spotify Web API** (Official) - [Documentation](https://developer.spotify.com/documentation/web-api)
- **Tidal API v2** (Official) - [Documentation](https://developer.tidal.com/documentation/api/api-overview)

## Testing

VCR is used for recording HTTP interactions:
```bash
rspec
```
