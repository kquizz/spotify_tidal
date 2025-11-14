# TidalAPI.md - Tidal OpenAPI Documentation

This document outlines the Tidal OpenAPI endpoints used in the application.

## Authentication

### Token Endpoint
- **URL**: `https://auth.tidal.com/v1/oauth2/token`
- **Method**: POST
- **Grant Type**: `client_credentials`
- **Headers**:
  - `Authorization`: Basic base64(client_id:client_secret)
- **Body**: `grant_type=client_credentials`
- **Response**: JSON with `access_token`

## Endpoints Used

### 1. Search Tracks
- **URL**: `https://openapi.tidal.com/v2/searchResults/{query}/relationships/tracks`
- **Method**: GET
- **Parameters**:
  - `countryCode`: "US"
  - `include`: "tracks"
- **Headers**:
  - `Authorization`: Bearer {access_token}
  - `accept`: application/vnd.api+json
- **Response**: JSON with `data` array of track objects

## Data Structures

### Track Object
```json
{
  "id": "string",
  "type": "tracks",
  "attributes": {
    "name": "string",
    "artists": [
      {
        "name": "string"
      }
    ],
    "album": {
      "name": "string"
    }
  }
}
```

### Response Structure
```json
{
  "data": [
    {
      "id": "string",
      "type": "tracks",
      "attributes": {
        "name": "string",
        "artists": [
          {
            "name": "string"
          }
        ],
        "album": {
          "name": "string"
        }
      }
    }
  ]
}
```</content>
<parameter name="filePath">/Users/kquillen/Code/spotify_tidal/TidalAPI.md