# Agent.md - Current Project Structure

This document provides an up-to-date overview of the project structure, including all method names and their line numbers in Ruby files.

## Controllers

### app/controllers/albums_controller.rb
- `index` (line 2)
- `show` (line 6)
- `create` (line 10)
- `destroy` (line 14)

### app/controllers/artists_controller.rb
- `index` (line 2)
- `show` (line 6)
- `destroy` (line 10)

### app/controllers/passwords_controller.rb
- `new` (line 8)
- `create` (line 11)
- `edit` (line 19)
- `update` (line 22)
- `set_user_by_token` (line 32)

### app/controllers/playlists_controller.rb
- `index` (line 2)
- `show` (line 6)
- `create` (line 10)
- `destroy` (line 21)
- `playlist_params` (line 29)
- `save_playlist_tracks(playlist)` (line 33)

### app/controllers/registrations_controller.rb
- `new` (line 4)
- `create` (line 8)
- `user_params` (line 20)

### app/controllers/sessions_controller.rb
- `new` (line 5)
- `create` (line 8)
- `destroy` (line 17)

### app/controllers/spotify_controller.rb
- `index` (line 2)
- `show` (line 13)
- `colors` (line 22)
- `sync` (line 25)
- `compare` (line 29)

### app/controllers/concerns/authentication.rb
- `allow_unauthenticated_access(**options)` (line 10)
- `authenticated?` (line 16)
- `current_user` (line 20)
- `require_authentication` (line 24)
- `resume_session` (line 28)
- `find_session_by_cookie` (line 32)
- `request_authentication` (line 36)
- `after_authentication_url` (line 41)
- `start_new_session_for(user)` (line 45)
- `terminate_session` (line 52)
- `login(user)` (line 57)

## Helpers

### app/helpers/application_helper.rb
- `get_color_default(i)` (line 3)

## Mailers

### app/mailers/passwords_mailer.rb
- `reset(user)` (line 2)

## Channels

### app/channels/application_cable/connection.rb
- `connect` (line 5)
- `set_current_user` (line 10)

## Services

### lib/spotify_service.rb
- `initialize(client_id: ENV["SPOTIFY_CLIENT_ID"], client_secret: ENV["SPOTIFY_CLIENT_SECRET"], refresh_token: ENV["SPOTIFY_REFRESH_TOKEN"])` (line 5)
- `liked_tracks(limit: 50)` (line 11)
- `user_playlists(user_id, limit: 50)` (line 31)
- `playlist_tracks(playlist_id, limit: 50)` (line 51)
- `playlists(limit: 50)` (line 75)
- `fetch_access_token` (line 96)

### lib/tidal_service.rb
- `initialize(client_id: ENV["TIDAL_CLIENT_ID"], client_secret: ENV["TIDAL_CLIENT_SECRET"])` (line 5)
- `search_track(track_name, artist_name, limit: 10)` (line 10)
- `fetch_access_token` (line 37)

## Database Migrations

### db/migrate/20251113022521_create_users.rb
- `change` (line 2)

### db/migrate/20251113022537_create_sessions.rb
- `change` (line 2)

### db/migrate/20251113040613_create_artists.rb
- `change` (line 2)

### db/migrate/20251113040621_create_albums.rb
- `change` (line 2)

### db/migrate/20251113040627_create_songs.rb
- `change` (line 2)

### db/migrate/20251113040639_create_playlists.rb
- `change` (line 2)

### db/migrate/20251113040645_create_playlist_songs.rb
- `change` (line 2)

### db/migrate/20251114035659_add_tidal_id_to_songs.rb
- `change` (line 2)

## Models

(Note: No methods found in model files from the search, as they likely use Rails conventions without explicit `def` for standard methods.)

## Other Files

- db/cable_schema.rb
- db/cache_schema.rb
- db/queue_schema.rb
- db/seeds.rb
- db/schema.rb
- script/get_refresh_token.rb
- spec/rails_helper.rb
- test/test_helper.rb
- test/application_system_test_case.rb
- app/mailers/application_mailer.rb
- app/jobs/application_job.rb
- app/models/album.rb
- app/models/application_record.rb
- app/models/artist.rb
- app/models/current.rb
- app/models/playlist_song.rb
- app/models/playlist.rb
- app/models/session.rb
- app/models/song.rb
- app/models/user.rb
- app/controllers/application_controller.rb
- config.ru
- Dockerfile
- Gemfile
- Procfile
- Rakefile
- README.md
- tailwind.config.js
- package.json
- bin/rails
- bin/rake
- bin/setup
- bin/bundler-audit
- bin/brakeman
- bin/ci
- bin/dev
- bin/docker-entrypoint
- bin/importmap
- bin/jobs
- bin/kamal
- bin/rubocop
- bin/thrust
- config/application.rb
- config/boot.rb
- config/bundler-audit.yml
- config/cable.yml
- config/cache.yml
- config/ci.rb
- config/credentials.yml.enc
- config/database.yml
- config/deploy.yml
- config/environment.rb
- config/importmap.rb
- config/master.key
- config/puma.rb
- config/queue.yml
- config/recurring.yml
- config/routes.rb
- config/shadcn.tailwind.js
- config/storage.yml
- config/environments/development.rb
- config/environments/production.rb
- config/environments/test.rb
- config/initializers/assets.rb
- lib/tasks/
- log/
- public/
- spec/
- storage/
- test/
- tmp/
- vendor/</content>
<parameter name="filePath">/Users/kquillen/Code/spotify_tidal/Agent.md