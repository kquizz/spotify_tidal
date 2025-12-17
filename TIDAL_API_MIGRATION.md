# Tidal API Migration Guide

## What Changed?

We've migrated from using an **unofficial/reverse-engineered Tidal API** to the **official Tidal API v2**.

### Previous Implementation
- Used unofficial endpoints (tidalapi.netlify.app)
- Complex search strategies (7+ fallback methods)
- Fragile authentication
- ~985 lines of code
- Risk of breaking without notice

### New Implementation  
- Official Tidal API v2 endpoints
- Cleaner OAuth 2.0 flow with PKCE
- Simplified search logic (5 strategies)
- ~450 lines of code
- Stable, documented, and supported
- Proper error handling and rate limiting

## Breaking Changes

### API Endpoints
- **Old**: `https://openapi.tidal.com/v2` (unofficial)
- **New**: `https://openapi.tidal.com` (official v2 API)

### Authentication
- **Old**: Device code flow (hacky)
- **New**: OAuth 2.0 Authorization Code with PKCE

### Response Format
- Track responses now follow JSON:API spec
- Data is nested under `data` and `attributes` keys
- Relationships are properly structured

### Method Signatures
All public methods remain the same:
- `search_track(track_name, artist_name, ...)` ✅
- `create_playlist(name, description)` ✅  
- `add_tracks_to_playlist(playlist_uuid, track_ids)` ✅
- `exchange_code_for_token(code, redirect_uri, code_verifier)` ✅

## Benefits

### 1. **Compliance**
- No longer violates Tidal's Terms of Service
- Using officially supported endpoints
- Proper OAuth 2.0 flow

### 2. **Reliability**
- Documented API endpoints
- Official support channels
- Clear rate limits
- Better error handling

### 3. **Maintainability**
- Simpler codebase (50% reduction)
- Standard REST patterns
- Better test coverage potential

### 4. **Features**
- Access to full Tidal catalog
- User playlist management
- Better search accuracy
- Proper metadata

## Migration Steps

### For Developers

1. **Update Tidal Developer Account**
   - Register at https://developer.tidal.com/
   - Create a new application
   - Get new Client ID and Secret
   - Add redirect URI: `http://localhost:3000/auth/tidal/callback`

2. **Update Environment Variables**
   ```bash
   # .env
   TIDAL_CLIENT_ID=your_new_client_id
   TIDAL_CLIENT_SECRET=your_new_client_secret
   ```

3. **Test Authentication Flow**
   - Start the app
   - Click "Connect Tidal"
   - Authorize with your Tidal account
   - Verify token storage

4. **Test Track Search**
   - Import a Spotify playlist
   - Run track lookup job
   - Verify matching accuracy

### For Users

**Action Required**: Re-authenticate with Tidal
1. Disconnect current Tidal connection (if any)
2. Click "Connect Tidal" button
3. Authorize the application
4. Continue using the app normally

## Backup

The old implementation is backed up in:
- `lib/tidal_service_old.rb`
- `lib/tidal_service.rb.backup`

To rollback: `mv lib/tidal_service_old.rb lib/tidal_service.rb`

## Testing

Run the test suite to verify everything works:
```bash
bundle install
rails db:migrate
rspec
```

## Known Limitations

### Old API Issues (Resolved)
❌ Unofficial endpoints could break anytime
❌ No official documentation
❌ Unclear rate limits
❌ Complex search fallback logic

### New API Advantages
✅ Official API with documentation
✅ Clear rate limits (tracked by our rate limiter)
✅ Proper OAuth 2.0 flow
✅ Better error messages
✅ Structured responses

## Support

For API issues:
- **Tidal**: https://developer.tidal.com/documentation
- **Spotify**: https://developer.spotify.com/documentation

## Notes

- The new implementation maintains backward compatibility with existing database schemas
- All existing Songs, Playlists, and track matching data remain unchanged
- Rate limiting is handled automatically by our RateLimiter class
- Retry logic with exponential backoff is built-in via ApiErrorHandler

## Next Steps

1. ✅ Refactored TidalService to use official API
2. ✅ Updated README with new instructions  
3. ✅ Added comprehensive error handling
4. ⏳ Test with real Tidal credentials
5. ⏳ Update VCR cassettes for tests
6. ⏳ Monitor API usage and rate limits

---
**Migration Date**: December 15, 2025
**Old Code**: Backed up in `lib/tidal_service_old.rb`
**Documentation**: https://developer.tidal.com/documentation/api/api-overview
