module Dormitory
  class Violation < ApplicationRecord
    # PURPOSE: Violation tracking for dormitory residents — type, place, description, status lifecycle (open→reviewed→closed), protocol file, and review details
    # SPECIFICATION: SPEC-DORM-10
    include Discard::Model
    include Trackable

    belongs_to :resident, class_name: "Dormitory::Resident"
    has_one_attached :protocol_file

    ACCEPTED_FILE_TYPES = %w[application/pdf image/jpeg image/png].freeze
    MAX_FILE_SIZE = 10.megabytes

    enum :violation_type, {
      noise: 0,
      property_damage: 1,
      smoking: 2,
      unauthorized_guests: 3,
      regime_violation: 4,
      unsanitary: 5,
      other: 6
    }

    enum :status, {
      open: 0,
      reviewed: 1,
      closed: 2
    }

    validates :resident, presence: true
    validates :violation_type, presence: true
    validates :occurred_at, presence: true
    validate :occurred_at_not_in_future
    validates :place, presence: true, length: { maximum: 255 }
    validates :description, presence: true, length: { maximum: 5000 }
    validates :commandant_comment, length: { maximum: 5000 }
    validates :review_result, length: { maximum: 5000 }
    validate :protocol_file_format_and_size
    validate :review_fields_present_when_reviewed_or_closed
    validate :review_fields_empty_when_open

    scope :ordered, -> { order(occurred_at: :desc) }
    scope :by_resident, ->(resident_id) { where(resident_id: resident_id) }

    def do_create!
      track_event("dormitory.violation.created") { save! }
    end

    def do_update!(attrs)
      track_event("dormitory.violation.updated") { update!(attrs) }
    end

    def do_discard!
      track_event("dormitory.violation.discarded") { discard! }
    end

    private

    def occurred_at_not_in_future
      return unless occurred_at
      return unless occurred_at > Time.current

      errors.add(:occurred_at, :not_in_future)
    end

    def protocol_file_format_and_size
      return unless protocol_file.attached?

      unless protocol_file.content_type.in?(ACCEPTED_FILE_TYPES)
        errors.add(:protocol_file, :invalid_file_format)
      end

      if protocol_file.byte_size > MAX_FILE_SIZE
        errors.add(:protocol_file, :file_too_large)
      end
    end

    def review_fields_present_when_reviewed_or_closed
      return unless reviewed? || closed?

      unless reviewed_at.present?
        errors.add(:reviewed_at, :required_when_reviewed)
      end

      unless review_result.present?
        errors.add(:review_result, :required_when_reviewed)
      end
    end

    def review_fields_empty_when_open
      return unless open?

      if reviewed_at.present?
        errors.add(:reviewed_at, :must_be_empty_when_open)
      end

      if review_result.present?
        errors.add(:review_result, :must_be_empty_when_open)
      end
    end
  end
end
