require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:',
)

connection = ActiveRecord::Base.connection

connection.create_table "delayed_jobs", force: true do |t|
  t.integer  "priority",   default: 0
  t.integer  "attempts",   default: 0
  t.text     "handler"
  t.text     "last_error"
  t.datetime "run_at"
  t.datetime "locked_at"
  t.datetime "failed_at"
  t.string   "locked_by"
  t.string   "queue"
  t.datetime "created_at",             null: false
  t.datetime "updated_at",             null: false
end

connection.add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"
