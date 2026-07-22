module Dormitory
  class Receipt < ApplicationRecord
    # PURPOSE: Payment receipt tracking — stores payment amounts with file attachments, linked to an accommodation
    # SPECIFICATION: SPEC-DORM-09
    include Discard::Model
    include Trackable

    belongs_to :accommodation, class_name: "Dormitory::Accommodation"

    has_one_attached :attachment

    ACCEPTED_FILE_TYPES = %w[application/pdf image/jpeg image/png].freeze
    MAX_FILE_SIZE = 10.megabytes

    validates :amount, numericality: { greater_than: 0 }
    validates :paid_at, presence: true
    validates :attachment, presence: true, on: :create
    validate :attachment_format_and_size, if: -> { attachment.attached? }

    scope :ordered, -> { order(paid_at: :desc) }

    def do_create!
      track_event("dormitory.receipt.created") { save! }
    end

    def do_update!(attrs)
      track_event("dormitory.receipt.updated") { update!(attrs) }
    end

    def do_discard!
      track_event("dormitory.receipt.destroyed") { discard! }
    end

    private

    def attachment_format_and_size
      unless attachment.content_type.in?(ACCEPTED_FILE_TYPES)
        errors.add(:attachment, :invalid_file_format)
      end

      if attachment.byte_size > MAX_FILE_SIZE
        errors.add(:attachment, :file_too_large)
      end
    end
  end
end
