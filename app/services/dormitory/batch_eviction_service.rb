module Dormitory
  class BatchEvictionService
    # PURPOSE: Orchestrates mass eviction with best-effort per-resident execution, creating BatchOperation with error tracking
    # SPECIFICATION: SPEC-DORM-05
    BATCH_EVICTION_REASONS = Dormitory::Accommodation::EVICTION_REASONS - %w[transfer]

    def initialize(academic_year:, building:, resident_ids:, eviction_reason:, performed_by:, comment: nil)
      @academic_year = academic_year
      @building = building
      @resident_ids = Array(resident_ids)
      @eviction_reason = eviction_reason
      @comment = comment
      @performed_by = performed_by
    end

    def call
      validate!
      create_batch_operation
      process_evictions
      @batch_operation
    ensure
      finish! if @batch_operation&.pending?
    end

    private

    def finish!
      status = @batch_operation.error_count.positive? ? "partial" : "completed"
      @batch_operation.do_complete!(status: status)
    end

    def validate!
      raise ArgumentError, I18n.t("dormitory.batch_operations.errors.reason_required") unless @eviction_reason.present?
      unless BATCH_EVICTION_REASONS.include?(@eviction_reason)
        raise ArgumentError, I18n.t("dormitory.batch_operations.errors.invalid_reason")
      end
      if @eviction_reason == "other" && @comment.blank?
        raise ArgumentError, I18n.t("dormitory.batch_operations.errors.comment_required")
      end
      raise ArgumentError, I18n.t("dormitory.batch_operations.errors.no_academic_year") unless @academic_year
      raise ArgumentError, I18n.t("dormitory.batch_operations.errors.no_building") unless @building
      raise ArgumentError, I18n.t("dormitory.batch_operations.errors.no_residents") if @resident_ids.empty?

      existing = Dormitory::Resident.where(id: @resident_ids).ids
      missing = @resident_ids.map(&:to_i) - existing
      if missing.any?
        raise ArgumentError, I18n.t("dormitory.batch_operations.errors.unknown_residents", ids: missing.join(", "))
      end
    end

    def create_batch_operation
      @batch_operation = Dormitory::BatchOperation.create!(
        academic_year: @academic_year,
        building: @building,
        operation_type: "mass_eviction",
        eviction_reason: @eviction_reason,
        comment: @comment,
        performed_by: @performed_by
      )
      @batch_operation.do_start!(@resident_ids.size)
    end

    def process_evictions
      @resident_ids.each do |resident_id|
        process_single_eviction(resident_id)
      end
    end

    def process_single_eviction(resident_id)
      resident = Dormitory::Resident.find_by(id: resident_id)
      accommodation = resident&.active_accommodation

      raise I18n.t("dormitory.batch_operations.errors.no_active_accommodation") unless accommodation
      raise I18n.t("dormitory.batch_operations.errors.wrong_building") unless accommodation.room.building_id == @building.id

      accommodation.do_evict!(eviction_reason: @eviction_reason, comment: @comment)
      @batch_operation.record_success!
    rescue StandardError => e
      @batch_operation.record_error!(
        resident: resident,
        accommodation: accommodation,
        error_message: e.message
      )
    end
  end
end
