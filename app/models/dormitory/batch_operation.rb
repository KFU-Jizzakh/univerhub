module Dormitory
  class BatchOperation < ApplicationRecord
    # PURPOSE: Tracks mass eviction batch operations with success/error counts, best-effort execution
    # SPECIFICATION: SPEC-DORM-05
    belongs_to :academic_year, class_name: "Dormitory::AcademicYear"
    belongs_to :building, class_name: "Dormitory::Building"
    belongs_to :performed_by, class_name: "User", optional: true

    has_many :batch_operation_errors, class_name: "Dormitory::BatchOperationError", dependent: :destroy

    validates :operation_type, presence: true, inclusion: { in: %w[mass_eviction] }
    validates :status, presence: true, inclusion: { in: %w[pending completed partial] }
    validates :total_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :success_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :error_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :ordered, -> { order(created_at: :desc) }

    def pending?
      status == "pending"
    end

    def completed?
      status == "completed"
    end

    def partial?
      status == "partial"
    end

    def do_start!(resident_count)
      update!(
        status: "pending",
        total_count: resident_count,
        success_count: 0,
        error_count: 0,
        started_at: Time.current
      )
    end

    def record_success!
      increment!(:success_count)
    end

    def record_error!(resident:, accommodation:, error_message:)
      increment!(:error_count)
      batch_operation_errors.create!(
        resident: resident,
        accommodation: accommodation,
        error_message: error_message
      )
    end

    def do_complete!(status: "completed")
      update!(
        status: status,
        completed_at: Time.current
      )
    end
  end
end
