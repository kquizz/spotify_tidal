# SpotifyAPI.md - Spotify Web API Documentation

This document outlines the Spotify Web API endpoints used in the application.

## Authentication

### Token Endpoint
- **URL**: `https://accounts.spotify.com/api/token`
- **Method**: POST
- **Grant Type**: `refresh_token`
- **Headers**:
  - `Authorization`: Basic base64(client_id:client_secret)
- **Body**: `grant_type=refresh_token&refresh_token={refresh_token}`
- **Response**: JSON with `access_token`

## Endpoints Used

### 1. Get User's Liked Tracks
- **URL**: `https://api.spotify.com/v1/me/tracks`
- **Method**: GET
- **Parameters**:
  - `limit` (optional, default 50): Number of tracks to return
- **Headers**:
  - `Authorization`: Bearer {access_token}
- **Response**: JSON array of track objects in `items`

### 2. Get User's Playlists
- **URL**: `https://api.spotify.com/v1/users/{user_id}/playlists`
- **Method**: GET
- **Parameters**:
  - `limit` (optional, default 50): Number of playlists to return
- **Headers**:
  - `Authorization`: Bearer {access_token}
- **Response**: JSON array of playlist objects in `items`

### 3. Get Playlist Tracks
- **URL**: `https://api.spotify.com/v1/playlists/{playlist_id}/tracks`
- **Method**: GET
- **Parameters**:
  - `limit` (optional, default 50): Number of tracks to return
- **Headers**:
  - `Authorization`: Bearer {access_token}
- **Response**: JSON array of track objects in `items`

### 4. Get Current User's Playlists
- **URL**: `https://api.spotify.com/v1/me/playlists`
- **Method**: GET
- **Parameters**:
  - `limit` (optional, default 50): Number of playlists to return
- **Headers**:
  - `Authorization`: Bearer {access_token}
- **Response**: JSON array of playlist objects in `items`

## Data Structures

### Track Object
```json
{
  "id": "string",
  "name": "string",
  "artists": [
    {
      "name": "string",
      "id": "string"
    }
  ],
  "album": {
    "name": "string",
    "id": "string",
    "images": [
      {
        "url": "string"
      }
    ]
  },
  "external_urls": {
    "spotify": "string"
  }
}
```

### Playlist Object
```json
{
  "id": "string",
  "name": "string",
  "owner": {
    "display_name": "string"
  },
  "tracks": {
    "total": 0
  },
  "public": true,
  "external_urls": {
    "spotify": "string"
  },
  "images": [
    {
      "url": "string"
    }
  ]
}
```</content>
<parameter name="filePath">/Users/kquillen/Code/spotify_tidal/SpotifyAPI.md