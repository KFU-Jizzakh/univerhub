require "test_helper"

module Dormitory
  class ResidentRegistrationServiceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      @scope = Dormitory::Room.kept
    end

    teardown do
      Current.reset
    end

    def resident_params(ticket: "SVC001")
      {
        last_name: "Сервис", first_name: "Тест", gender: :male, course: 1,
        date_of_birth: 20.years.ago, student_ticket_number: ticket
      }
    end

    def files_params
      {
        application_number: "З-СВ", contract_number: "Д-СВ",
        application_file: {
          io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
        },
        contract_file: {
          io: StringIO.new("contract"), filename: "contract.pdf", content_type: "application/pdf"
        }
      }
    end

    test "manual room and bed are used when placement is requested" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC001").merge(files_params),
        place: true,
        manual_room_id: dormitory_rooms(:room_101).id,
        manual_bed_label: "C"
      )

      assert_equal :pending, result
      acc = service.accommodation
      assert_equal dormitory_rooms(:room_101).id, acc.room_id
      assert_equal "C", acc.bed_label
      assert_equal "not_settled", service.resident.status
      assert acc.pending?
    end

    test "without place creates resident only" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC002"),
        place: false
      )

      assert_equal :created, result
      assert_nil service.accommodation
      assert_equal "not_settled", service.resident.status
    end

    test "placement without a room raises and does not create the resident" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC003").merge(files_params),
          place: true
        )
      end

      assert_equal [ :room_required ], service.resident.errors.details[:base].map { |d| d[:error] }
      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC003")
    end

    test "placement with a room but without a bed raises and does not create the resident" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC004").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_101).id
        )
      end

      assert_equal [ :bed_required ], service.resident.errors.details[:base].map { |d| d[:error] }
      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC004")
    end

    test "placement into a room outside the scope raises" do
      scope = Dormitory::Room.where(building: dormitory_buildings(:building_one))
      service = ResidentRegistrationService.new(room_scope: scope)

      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC005").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_101_building_two).id,
          manual_bed_label: "A"
        )
      end

      assert_equal [ :room_required ], service.resident.errors.details[:base].map { |d| d[:error] }
      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC005")
    end

    test "taken bed label raises and rolls back the resident" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC006").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_201).id,
          manual_bed_label: "A"
        )
      end

      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC006")
    end

    test "creates required amount and receipt on the pending accommodation" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC007").merge(files_params),
        place: true,
        manual_room_id: dormitory_rooms(:room_101).id,
        manual_bed_label: "C",
        required_amount: "12000",
        receipt_params: {
          amount: "5000",
          paid_at: Date.current,
          attachment: { io: StringIO.new("receipt"), filename: "receipt1.pdf", content_type: "application/pdf" }
        }
      )

      assert_equal :pending, result
      acc = service.accommodation
      assert acc.pending?
      assert_equal 12_000, acc.required_amount.to_f
      assert_equal "C", acc.bed_label
      receipt = service.receipt
      assert_equal acc, receipt.accommodation
      assert_equal 5_000, receipt.amount.to_f
      assert_equal Date.current, receipt.paid_at
      assert receipt.attachment.attached?
      assert_equal "receipt1.pdf", receipt.attachment.filename.to_s
      assert_equal 5_000, acc.total_paid.to_f
      assert_equal(-7_000, acc.balance.to_f)
      assert_equal "dormitory.receipt.created", OutboxEvent.where(record: receipt, action: "dormitory.receipt.created").last.action
    end

    test "empty payment fields create no receipt" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC008").merge(files_params),
        place: true,
        manual_room_id: dormitory_rooms(:room_101).id,
        manual_bed_label: "C",
        required_amount: nil,
        receipt_params: {}
      )

      assert_equal :pending, result
      assert_nil service.receipt
      assert_equal 0, service.accommodation.required_amount.to_f
      assert_empty service.accommodation.receipts
    end

    test "receipt requested with blank paid date defaults to today" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC008b").merge(files_params),
        place: true,
        manual_room_id: dormitory_rooms(:room_101).id,
        manual_bed_label: "C",
        receipt_params: {
          amount: "5000",
          attachment: { io: StringIO.new("receipt"), filename: "receipt1.pdf", content_type: "application/pdf" }
        }
      )

      assert_equal :pending, result
      assert_equal Date.current, service.receipt.paid_at
    end

    test "placement disabled with receipt params creates no receipt" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      result = service.call(
        resident_params: resident_params(ticket: "SVC009"),
        place: false,
        receipt_params: {
          amount: "5000",
          paid_at: Date.current,
          attachment: { io: StringIO.new("receipt"), filename: "receipt1.pdf", content_type: "application/pdf" }
        }
      )

      assert_equal :created, result
      assert_nil service.accommodation
      assert_nil service.receipt
    end

    test "invalid receipt raises and rolls back the resident" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC010").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_101).id,
          manual_bed_label: "C",
          receipt_params: {
            amount: "5000",
            paid_at: Date.current
          }
        )
      end

      assert service.resident.errors.any?
      base_messages = service.resident.errors[:base]
      assert base_messages.any? { |m| m.start_with?("#{I18n.t("views.dormitory.residents.payment_section")}:") }
      assert base_messages.any? { |m| m.include?(I18n.t("activerecord.errors.messages.blank")) }
      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC010")
      assert_empty Dormitory::Receipt.where(accommodation: service.accommodation)
    end

    test "receipt with amount below or equal to zero raises and rolls back" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC011").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_101).id,
          manual_bed_label: "C",
          receipt_params: {
            amount: "0",
            paid_at: Date.current,
            attachment: { io: StringIO.new("receipt"), filename: "receipt1.pdf", content_type: "application/pdf" }
          }
        )
      end

      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC011")
    end

    test "negative required amount raises and rolls back" do
      service = ResidentRegistrationService.new(room_scope: @scope)
      assert_raises(ActiveRecord::RecordInvalid) do
        service.call(
          resident_params: resident_params(ticket: "SVC012").merge(files_params),
          place: true,
          manual_room_id: dormitory_rooms(:room_101).id,
          manual_bed_label: "C",
          required_amount: "-100"
        )
      end

      assert service.resident.errors[:required_amount].any?
      assert_nil Dormitory::Resident.find_by(student_ticket_number: "SVC012")
    end
  end
end
