# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_16_040450) do
  create_table "albums", force: :cascade do |t|
    t.integer "artist_id", null: false
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "name"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_albums_on_artist_id"
    t.index ["spotify_id"], name: "index_albums_on_spotify_id", unique: true
  end

  create_table "artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_artists_on_name"
    t.index ["spotify_id"], name: "index_artists_on_spotify_id", unique: true
  end

  create_table "playlist_songs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "playlist_id", null: false
    t.integer "song_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id", "song_id"], name: "index_playlist_songs_on_playlist_id_and_song_id", unique: true
    t.index ["playlist_id"], name: "index_playlist_songs_on_playlist_id"
    t.index ["song_id"], name: "index_playlist_songs_on_song_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "import_status"
    t.text "last_import_error"
    t.string "name"
    t.string "owner"
    t.string "spotify_id"
    t.string "tidal_playlist_id"
    t.integer "tracks_total"
    t.datetime "updated_at", null: false
    t.index ["import_status"], name: "index_playlists_on_import_status"
    t.index ["spotify_id"], name: "index_playlists_on_spotify_id", unique: true
    t.index ["tidal_playlist_id"], name: "index_playlists_on_tidal_playlist_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "idx_sq_blocked_release"
    t.index ["expires_at", "concurrency_key"], name: "idx_sq_blocked_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "idx_sq_claimed_pid_job"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "idx_sq_jobs_filtering"
    t.index ["scheduled_at", "finished_at"], name: "idx_sq_jobs_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name"
    t.string "namespace"
    t.integer "pid", null: false
    t.bigint "process_id"
    t.string "supervisor_id"
    t.datetime "updated_at", null: false
    t.index ["kind", "process_id", "supervisor_id"], name: "idx_sq_processes_kind_pid_sup"
    t.index ["last_heartbeat_at"], name: "idx_sq_processes_heartbeat"
    t.index ["supervisor_id"], name: "idx_sq_processes_supervisor"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "idx_sq_ready_priority"
    t.index ["queue_name", "priority", "job_id"], name: "idx_sq_ready_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key"], name: "index_solid_queue_recurring_executions_on_task_key", unique: true
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "idx_sq_sched_priority"
    t.index ["scheduled_at", "priority", "job_id"], name: "idx_sq_sched_time"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "idx_sq_semaphores_key_val"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "songs", force: :cascade do |t|
    t.integer "album_id", null: false
    t.integer "artist_id", null: false
    t.datetime "created_at", null: false
    t.string "isrc"
    t.text "lookup_log"
    t.string "name"
    t.string "spotify_id"
    t.string "tidal_artist_name"
    t.string "tidal_id"
    t.string "tidal_track_name"
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_songs_on_album_id"
    t.index ["artist_id"], name: "index_songs_on_artist_id"
    t.index ["spotify_id"], name: "index_songs_on_spotify_id", unique: true
    t.index ["tidal_id"], name: "index_songs_on_tidal_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "tidal_access_token"
    t.datetime "tidal_expires_at"
    t.string "tidal_refresh_token"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "albums", "artists"
  add_foreign_key "playlist_songs", "playlists"
  add_foreign_key "playlist_songs", "songs"
  add_foreign_key "sessions", "users"
  add_foreign_key "songs", "albums"
  add_foreign_key "songs", "artists"
end
