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

ActiveRecord::Schema[8.1].define(version: 2026_05_26_042942) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "dormitory_academic_years", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_dormitory_academic_years_on_discarded_at"
    t.index ["name"], name: "index_dormitory_academic_years_on_name", unique: true, where: "(discarded_at IS NULL)"
    t.index ["status"], name: "idx_academic_years_active", unique: true, where: "((status)::text = 'active'::text)"
  end

  create_table "dormitory_accommodations", force: :cascade do |t|
    t.bigint "academic_year_id", null: false
    t.date "actual_end_date"
    t.string "application_number", null: false
    t.text "comment"
    t.string "contract_number", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "eviction_reason"
    t.date "planned_end_date", null: false
    t.bigint "renewal_source_id"
    t.bigint "resident_id", null: false
    t.bigint "room_id", null: false
    t.date "start_date", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_year_id"], name: "index_dormitory_accommodations_on_academic_year_id"
    t.index ["discarded_at"], name: "index_dormitory_accommodations_on_discarded_at"
    t.index ["planned_end_date"], name: "idx_accommodations_planned_end_date"
    t.index ["renewal_source_id"], name: "index_dormitory_accommodations_on_renewal_source_id"
    t.index ["resident_id"], name: "idx_active_accommodation", unique: true, where: "(((status)::text = 'active'::text) AND (discarded_at IS NULL))"
    t.index ["resident_id"], name: "index_dormitory_accommodations_on_resident_id"
    t.index ["room_id"], name: "index_dormitory_accommodations_on_room_id"
    t.index ["status"], name: "index_dormitory_accommodations_on_status"
  end

  create_table "dormitory_batch_operation_errors", force: :cascade do |t|
    t.bigint "accommodation_id"
    t.bigint "batch_operation_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "resident_id"
    t.datetime "updated_at", null: false
    t.index ["accommodation_id"], name: "index_dormitory_batch_operation_errors_on_accommodation_id"
    t.index ["batch_operation_id"], name: "index_dormitory_batch_operation_errors_on_batch_operation_id"
    t.index ["resident_id"], name: "index_dormitory_batch_operation_errors_on_resident_id"
  end

  create_table "dormitory_batch_operations", force: :cascade do |t|
    t.bigint "academic_year_id", null: false
    t.bigint "building_id", null: false
    t.text "comment"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0
    t.string "eviction_reason"
    t.string "operation_type", null: false
    t.bigint "performed_by_id"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "success_count", default: 0
    t.integer "total_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["academic_year_id"], name: "index_dormitory_batch_operations_on_academic_year_id"
    t.index ["building_id"], name: "index_dormitory_batch_operations_on_building_id"
    t.index ["performed_by_id"], name: "index_dormitory_batch_operations_on_performed_by_id"
    t.index ["status"], name: "index_dormitory_batch_operations_on_status"
  end

  create_table "dormitory_buildings", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.integer "floors_count", default: 1, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_dormitory_buildings_on_discarded_at"
    t.index ["name"], name: "index_dormitory_buildings_on_name", unique: true
  end

  create_table "dormitory_commandant_buildings", force: :cascade do |t|
    t.bigint "building_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["building_id"], name: "index_dormitory_commandant_buildings_on_building_id"
    t.index ["user_id", "building_id"], name: "index_active_commandant_buildings", unique: true, where: "(deactivated_at IS NULL)"
    t.index ["user_id"], name: "index_dormitory_commandant_buildings_on_user_id"
  end

  create_table "dormitory_residents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_room_id"
    t.date "date_of_birth", null: false
    t.datetime "discarded_at"
    t.string "email"
    t.string "first_name", null: false
    t.integer "gender", default: 0, null: false
    t.string "last_name", null: false
    t.string "middle_name"
    t.string "phone"
    t.integer "status", default: 0, null: false
    t.string "student_ticket_number", null: false
    t.datetime "updated_at", null: false
    t.index ["current_room_id"], name: "index_dormitory_residents_on_current_room_id"
    t.index ["discarded_at"], name: "index_dormitory_residents_on_discarded_at"
    t.index ["student_ticket_number"], name: "index_dormitory_residents_on_ticket_unique_kept", unique: true, where: "(discarded_at IS NULL)"
  end

  create_table "dormitory_rooms", force: :cascade do |t|
    t.bigint "building_id", null: false
    t.integer "capacity", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "current_occupancy", default: 0, null: false
    t.datetime "discarded_at"
    t.integer "floor", null: false
    t.integer "gender_restriction"
    t.string "number", null: false
    t.string "status", default: "free", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id", "number"], name: "index_dormitory_rooms_on_building_id_and_number", unique: true, where: "(discarded_at IS NULL)"
    t.index ["building_id"], name: "index_dormitory_rooms_on_building_id"
    t.index ["discarded_at"], name: "index_dormitory_rooms_on_discarded_at"
    t.index ["status"], name: "index_dormitory_rooms_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "outbox_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.jsonb "payload", default: {}
    t.integer "record_id"
    t.string "record_type"
    t.datetime "updated_at", null: false
    t.index ["actor_id", "created_at"], name: "index_outbox_events_on_actor_id_and_created_at"
    t.index ["actor_id"], name: "index_outbox_events_on_actor_id"
    t.index ["record_type", "record_id"], name: "index_outbox_events_on_record_type_and_record_id"
  end

  create_table "reporting_report_comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["report_id"], name: "index_reporting_report_comments_on_report_id"
    t.index ["user_id"], name: "index_reporting_report_comments_on_user_id"
  end

  create_table "reporting_report_items", force: :cascade do |t|
    t.boolean "attachments_required", default: false, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "grade"
    t.text "grade_comment"
    t.integer "max_grade"
    t.string "name", null: false
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_reporting_report_items_on_report_id"
  end

  create_table "reporting_report_template_items", force: :cascade do |t|
    t.boolean "attachments_required", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "max_grade"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "report_template_id", null: false
    t.datetime "updated_at", null: false
    t.index ["report_template_id"], name: "index_reporting_report_template_items_on_report_template_id"
  end

  create_table "reporting_report_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description"
    t.string "name", null: false
    t.string "pdf_template"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_reporting_report_templates_on_creator_id"
  end

  create_table "reporting_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.datetime "deadline"
    t.text "description"
    t.datetime "discarded_at"
    t.string "name", null: false
    t.text "rejection_reason"
    t.bigint "report_template_id"
    t.bigint "reporter_id"
    t.datetime "reviewed_at"
    t.bigint "reviewer_id"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.integer "total_grade"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_reporting_reports_on_creator_id"
    t.index ["discarded_at"], name: "index_reporting_reports_on_discarded_at"
    t.index ["reporter_id"], name: "index_reporting_reports_on_reporter_id"
    t.index ["reviewer_id"], name: "index_reporting_reports_on_reviewer_id"
    t.index ["status", "created_at"], name: "index_reporting_reports_on_status_and_created_at", order: { created_at: :desc }
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "user_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_profiles_on_user_id", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.datetime "discarded_at"
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "dormitory_accommodations", "dormitory_academic_years", column: "academic_year_id"
  add_foreign_key "dormitory_accommodations", "dormitory_accommodations", column: "renewal_source_id"
  add_foreign_key "dormitory_accommodations", "dormitory_residents", column: "resident_id"
  add_foreign_key "dormitory_accommodations", "dormitory_rooms", column: "room_id"
  add_foreign_key "dormitory_batch_operation_errors", "dormitory_accommodations", column: "accommodation_id"
  add_foreign_key "dormitory_batch_operation_errors", "dormitory_batch_operations", column: "batch_operation_id"
  add_foreign_key "dormitory_batch_operation_errors", "dormitory_residents", column: "resident_id"
  add_foreign_key "dormitory_batch_operations", "dormitory_academic_years", column: "academic_year_id"
  add_foreign_key "dormitory_batch_operations", "dormitory_buildings", column: "building_id"
  add_foreign_key "dormitory_batch_operations", "users", column: "performed_by_id"
  add_foreign_key "dormitory_commandant_buildings", "dormitory_buildings", column: "building_id"
  add_foreign_key "dormitory_commandant_buildings", "users"
  add_foreign_key "dormitory_residents", "dormitory_rooms", column: "current_room_id"
  add_foreign_key "dormitory_rooms", "dormitory_buildings", column: "building_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "outbox_events", "users", column: "actor_id"
  add_foreign_key "reporting_report_comments", "reporting_reports", column: "report_id"
  add_foreign_key "reporting_report_comments", "users"
  add_foreign_key "reporting_report_items", "reporting_reports", column: "report_id"
  add_foreign_key "reporting_report_template_items", "reporting_report_templates", column: "report_template_id"
  add_foreign_key "reporting_report_templates", "users", column: "creator_id"
  add_foreign_key "reporting_reports", "reporting_report_templates", column: "report_template_id"
  add_foreign_key "reporting_reports", "users", column: "creator_id"
  add_foreign_key "reporting_reports", "users", column: "reporter_id"
  add_foreign_key "reporting_reports", "users", column: "reviewer_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_profiles", "users"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
