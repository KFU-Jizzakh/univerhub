require "test_helper"
require "rake"

class DormitoryTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("dormitory:backfill_transfer_receipts")
    @task = Rake::Task["dormitory:backfill_transfer_receipts"]
    @room_101 = dormitory_rooms(:room_101)
    @room_102 = dormitory_rooms(:room_102)
  end

  private

  def with_env(name, value)
    old = ENV[name]
    ENV[name] = value
    yield
  ensure
    old.nil? ? ENV.delete(name) : ENV[name] = old
  end

  def run_task
    stdout = StringIO.new
    old_stdout = $stdout
    $stdout = stdout
    @task.invoke
  ensure
    $stdout = old_stdout
    @task.reenable
  end

  def create_pair
    resident = Dormitory::Resident.create!(
      last_name: "Таск#{("а".."я").to_a.sample(3).join}", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "TK#{SecureRandom.hex(4)}"
    )
    old_acc = Dormitory::Accommodation.new(
      resident: resident, room: @room_101,
      application_number: "З-TK#{SecureRandom.hex(3)}", contract_number: "Д-TK#{SecureRandom.hex(3)}",
      start_date: Date.current - 100.days, planned_end_date: Date.current - 50.days
    )
    old_acc.actual_end_date = Date.current - 3.days
    old_acc.eviction_reason = "transfer"
    old_acc.complete!
    successor = Dormitory::Accommodation.create!(
      resident: resident, room: @room_102,
      application_number: "З-TS#{SecureRandom.hex(3)}", contract_number: "Д-TS#{SecureRandom.hex(3)}",
      start_date: Date.current - 3.days, planned_end_date: Date.current + 1.year
    )
    receipt = old_acc.receipts.build(amount: 5000, paid_at: Date.current)
    receipt.attachment.attach(io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf")
    receipt.save!
    [ old_acc, successor ]
  end

  def assert_applied(old_acc, successor)
    assert_equal 0, Dormitory::Receipt.with_discarded.where(accommodation_id: old_acc.id).count
    assert_equal 1, Dormitory::Receipt.with_discarded.where(accommodation_id: successor.id).count
  end

  def assert_dry_run(old_acc, successor)
    assert_equal 1, Dormitory::Receipt.with_discarded.where(accommodation_id: old_acc.id).count
    assert_equal 0, Dormitory::Receipt.with_discarded.where(accommodation_id: successor.id).count
  end

  test "applies the backfill by default" do
    old_acc, successor = create_pair
    run_task
    assert_applied(old_acc, successor)
  end

  test "DRY_RUN=0 applies the backfill" do
    old_acc, successor = create_pair
    with_env("DRY_RUN", "0") { run_task }
    assert_applied(old_acc, successor)
  end

  test "DRY_RUN=false applies the backfill" do
    old_acc, successor = create_pair
    with_env("DRY_RUN", "false") { run_task }
    assert_applied(old_acc, successor)
  end

  test "DRY_RUN=1 runs a dry run" do
    old_acc, successor = create_pair
    with_env("DRY_RUN", "1") { run_task }
    assert_dry_run(old_acc, successor)
  end

  test "DRY_RUN=true runs a dry run" do
    old_acc, successor = create_pair
    with_env("DRY_RUN", "true") { run_task }
    assert_dry_run(old_acc, successor)
  end
end
