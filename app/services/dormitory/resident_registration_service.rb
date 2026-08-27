module Dormitory
  # PURPOSE: Creates a resident and, when placement is requested, registers a pending accommodation into the user-chosen room and bed; a missing room or bed is a form error and the resident is not created. Optionally sets the accommodation required amount and creates a payment receipt on the pending accommodation when receipt fields are provided
  # SPECIFICATION: SPEC-DORM-12
  class ResidentRegistrationService
    attr_reader :resident, :accommodation, :receipt

    def initialize(room_scope: Dormitory::Room.kept)
      @room_scope = room_scope
    end

    # Returns :created (no placement) or :pending (pending accommodation created)
    def call(resident: nil, resident_params:, place: false, manual_room_id: nil, manual_bed_label: nil,
             start_date: nil, planned_end_date: nil, required_amount: nil, receipt_params: {})
      @resident = resident || Dormitory::Resident.new(resident_params)
      @resident.validate!

      unless place
        @resident.do_create!
        return :created
      end

      room = chosen_room(manual_room_id)
      if room.nil?
        @resident.errors.add(:base, :room_required)
        raise ActiveRecord::RecordInvalid.new(@resident)
      end

      if manual_bed_label.to_s.strip.blank?
        @resident.errors.add(:base, :bed_required)
        raise ActiveRecord::RecordInvalid.new(@resident)
      end

      ActiveRecord::Base.transaction do
        @resident.do_create!
        @accommodation = register_in_room(room, manual_bed_label, start_date, planned_end_date, required_amount)
        create_receipt!(receipt_params) if receipt_requested?(receipt_params)
      end

      :pending
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(Dormitory::Receipt)
        @resident.errors.add(:base,
          "#{I18n.t("views.dormitory.residents.payment_section")}: #{e.record.errors.full_messages.join(", ")}")
      else
        @resident.errors.merge!(e.record.errors) unless e.record == @resident
      end
      raise ActiveRecord::RecordInvalid.new(@resident)
    end

    private

    # PURPOSE: Returns the user-chosen room within the visible scope, or nil when the room is missing or out of scope
    # SPECIFICATION: SPEC-DORM-12
    def chosen_room(manual_room_id)
      return nil if manual_room_id.to_s.strip.blank?

      @room_scope.find_by(id: manual_room_id)
    end

    def register_in_room(room, manual_bed_label, start_date, planned_end_date, required_amount)
      accommodation = Dormitory::Accommodation.new(
        resident: @resident,
        room: room,
        start_date: start_date || Date.current,
        planned_end_date: planned_end_date || Date.current + 1.year,
        required_amount: cast_decimal(required_amount) || 0
      )
      @resident.copy_documents_to(accommodation)
      accommodation.do_register!(force: false, bed_label: manual_bed_label.to_s.strip)
      accommodation
    end

    # PURPOSE: Creates a receipt on the pending accommodation, raising RecordInvalid (transaction rollback) when the receipt is invalid
    # SPECIFICATION: SPEC-DORM-12
    def create_receipt!(receipt_params)
      @receipt = Dormitory::Receipt.new(
        accommodation: @accommodation,
        amount: cast_decimal(receipt_params[:amount]),
        paid_at: receipt_params[:paid_at].presence || Date.current,
        attachment: receipt_params[:attachment]
      )
      @receipt.do_create!
    end

    # PURPOSE: A receipt is requested when any of its fields (file, amount, or paid date) is present
    # SPECIFICATION: SPEC-DORM-12
    def receipt_requested?(receipt_params)
      receipt_params[:attachment].present? || cast_decimal(receipt_params[:amount]).present? ||
        receipt_params[:paid_at].present?
    end

    def cast_decimal(value)
      ActiveModel::Type::Decimal.new.cast(value)
    end
  end
end
