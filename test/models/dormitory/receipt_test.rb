require "test_helper"

module Dormitory
  class ReceiptTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      @accommodation = dormitory_accommodations(:active_accommodation)
      @accommodation.update!(status: :active)
    end

    teardown do
      Current.reset
    end

    def build_receipt(overrides = {})
      attrs = {
        accommodation: @accommodation,
        amount: 5000,
        paid_at: Date.current
      }.merge(overrides)
      Receipt.new(attrs)
    end

    def attach_pdf(receipt)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
    end

    def create_receipt(overrides = {})
      receipt = build_receipt(overrides)
      attach_pdf(receipt) unless overrides.key?(:skip_attach)
      receipt.do_create!
      receipt
    end

    # --- Validations ---

    test "valid receipt" do
      receipt = build_receipt
      attach_pdf(receipt)
      assert receipt.valid?
    end

    test "amount must be greater than zero" do
      receipt = build_receipt(amount: 0)
      attach_pdf(receipt)
      assert_not receipt.valid?
      assert receipt.errors[:amount].any?
    end

    test "amount cannot be negative" do
      receipt = build_receipt(amount: -100)
      attach_pdf(receipt)
      assert_not receipt.valid?
      assert receipt.errors[:amount].any?
    end

    test "paid_at is required" do
      receipt = build_receipt(paid_at: nil)
      attach_pdf(receipt)
      assert_not receipt.valid?
      assert receipt.errors[:paid_at].any?
    end

    test "attachment is required on create" do
      receipt = build_receipt
      assert_not receipt.valid?
      assert receipt.errors[:attachment].any?
    end

    test "attachment can be changed on update" do
      receipt = create_receipt
      receipt.attachment.attach(
        io: StringIO.new("updated"), filename: "new_receipt.pdf", content_type: "application/pdf"
      )
      assert receipt.valid?
    end

    test "rejects invalid file format" do
      receipt = build_receipt
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.txt", content_type: "text/plain"
      )
      assert_not receipt.valid?
      assert_includes receipt.errors[:attachment],
        I18n.t("activerecord.errors.models.dormitory/receipt.attributes.attachment.invalid_file_format")
    end

    test "rejects oversized file" do
      receipt = build_receipt
      receipt.attachment.attach(
        io: StringIO.new("x" * 11.megabytes), filename: "big.pdf", content_type: "application/pdf"
      )
      assert_not receipt.valid?
      assert_includes receipt.errors[:attachment],
        I18n.t("activerecord.errors.models.dormitory/receipt.attributes.attachment.file_too_large")
    end

    # --- Trackable events ---

    test "do_create! logs audit event" do
      receipt = build_receipt
      attach_pdf(receipt)
      assert_difference -> { OutboxEvent.count }, 1 do
        receipt.do_create!
      end
      event = OutboxEvent.last
      assert_equal "dormitory.receipt.created", event.action
      assert_equal receipt, event.record
    end

    test "do_update! logs audit event" do
      receipt = create_receipt
      assert_difference -> { OutboxEvent.count }, 1 do
        receipt.do_update!(amount: 6000)
      end
      event = OutboxEvent.last
      assert_equal "dormitory.receipt.updated", event.action
      assert_equal receipt, event.record
    end

    test "do_discard! logs audit event and soft-deletes" do
      receipt = create_receipt
      assert_difference -> { OutboxEvent.count }, 1 do
        receipt.do_discard!
      end
      event = OutboxEvent.last
      assert_equal "dormitory.receipt.destroyed", event.action
      assert receipt.discarded?
    end

    # --- Discard ---

    test "kept scope excludes discarded receipts" do
      kept = create_receipt(amount: 1000)
      discarded = create_receipt(amount: 2000)
      discarded.discard!

      kept_receipts = Receipt.kept
      assert_includes kept_receipts, kept
      assert_not_includes kept_receipts, discarded
    end

    test "discarded receipt is not physically deleted" do
      receipt = create_receipt
      receipt.do_discard!
      assert Receipt.with_discarded.exists?(receipt.id)
    end

    # --- Ordered scope ---

    test "ordered scope sorts by paid_at descending" do
      today = create_receipt(amount: 3000, paid_at: Date.current)
      yesterday = create_receipt(amount: 1000, paid_at: Date.current - 1)
      tomorrow = create_receipt(amount: 5000, paid_at: Date.current + 1)

      ordered = Receipt.ordered

      assert_equal tomorrow, ordered[0]
      assert_equal today, ordered[1]
      assert_equal yesterday, ordered[2]
    end

    # --- Association ---

    test "association returns accommodation" do
      receipt = create_receipt
      assert_equal @accommodation, receipt.accommodation
      assert_includes @accommodation.receipts.kept, receipt
    end
  end
end
