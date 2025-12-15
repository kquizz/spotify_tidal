class CreateSolidQueueTables < ActiveRecord::Migration[8.1]
  def change
    create_table "solid_queue_blocked_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.string "concurrency_key", null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.index [ "concurrency_key", "priority", "job_id" ], name: "idx_sq_blocked_release"
      t.index [ "expires_at", "concurrency_key" ], name: "idx_sq_blocked_maintenance"
      t.index [ "job_id" ], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
    end

    create_table "solid_queue_claimed_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.bigint "process_id"
      t.datetime "created_at", null: false
      t.index [ "job_id" ], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
      t.index [ "process_id", "job_id" ], name: "idx_sq_claimed_pid_job"
    end

    create_table "solid_queue_failed_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.text "error"
      t.datetime "created_at", null: false
      t.index [ "job_id" ], name: "index_solid_queue_failed_executions_on_job_id", unique: true
    end

    create_table "solid_queue_jobs", force: :cascade do |t|
      t.string "queue_name", null: false
      t.string "class_name", null: false
      t.text "arguments"
      t.integer "priority", default: 0, null: false
      t.string "active_job_id"
      t.datetime "scheduled_at"
      t.datetime "finished_at"
      t.string "concurrency_key"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "active_job_id" ], name: "index_solid_queue_jobs_on_active_job_id"
      t.index [ "class_name" ], name: "index_solid_queue_jobs_on_class_name"
      t.index [ "finished_at" ], name: "index_solid_queue_jobs_on_finished_at"
      t.index [ "queue_name", "finished_at" ], name: "idx_sq_jobs_filtering"
      t.index [ "scheduled_at", "finished_at" ], name: "idx_sq_jobs_alerting"
    end

    create_table "solid_queue_pauses", force: :cascade do |t|
      t.string "queue_name", null: false
      t.datetime "created_at", null: false
      t.index [ "queue_name" ], name: "index_solid_queue_pauses_on_queue_name", unique: true
    end

    create_table "solid_queue_processes", force: :cascade do |t|
      t.string "kind", null: false
      t.datetime "last_heartbeat_at", null: false
      t.bigint "process_id"
      t.string "supervisor_id"
      t.string "hostname"
      t.integer "pid", null: false
      t.string "namespace"
      t.text "metadata"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "kind", "process_id", "supervisor_id" ], name: "idx_sq_processes_kind_pid_sup"
      t.index [ "last_heartbeat_at" ], name: "idx_sq_processes_heartbeat"
      t.index [ "supervisor_id" ], name: "idx_sq_processes_supervisor"
    end

    create_table "solid_queue_ready_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "created_at", null: false
      t.index [ "job_id" ], name: "index_solid_queue_ready_executions_on_job_id", unique: true
      t.index [ "priority", "job_id" ], name: "idx_sq_ready_priority"
      t.index [ "queue_name", "priority", "job_id" ], name: "idx_sq_ready_queue"
    end

    create_table "solid_queue_recurring_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "task_key", null: false
      t.datetime "run_at", null: false
      t.datetime "created_at", null: false
      t.index [ "job_id" ], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
      t.index [ "task_key" ], name: "index_solid_queue_recurring_executions_on_task_key", unique: true
    end

    create_table "solid_queue_scheduled_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "scheduled_at", null: false
      t.datetime "created_at", null: false
      t.index [ "job_id" ], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
      t.index [ "scheduled_at", "priority", "job_id" ], name: "idx_sq_sched_priority"
      t.index [ "scheduled_at", "priority", "job_id" ], name: "idx_sq_sched_time"
    end

    create_table "solid_queue_semaphores", force: :cascade do |t|
      t.string "key", null: false
      t.integer "value", default: 1, null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "expires_at" ], name: "index_solid_queue_semaphores_on_expires_at"
      t.index [ "key", "value" ], name: "idx_sq_semaphores_key_val"
      t.index [ "key" ], name: "index_solid_queue_semaphores_on_key", unique: true
    end
  end
end
