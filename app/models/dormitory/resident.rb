module Dormitory
  class Resident < ApplicationRecord
    # PURPOSE: Resident personal data, status lifecycle (not_settled→settled→temporarily_absent→evicted), search, and photo management
    # SPECIFICATION: SPEC-DORM-03
    include Discard::Model
    include Trackable

    belongs_to :current_room, class_name: "Dormitory::Room", optional: true

    has_many :accommodations, class_name: "Dormitory::Accommodation", dependent: :restrict_with_error
    has_one :active_accommodation, -> { where(status: :active) }, class_name: "Dormitory::Accommodation"
    has_many :violations, class_name: "Dormitory::Violation", dependent: :restrict_with_error
    has_one_attached :photo
    has_one_attached :application_file
    has_one_attached :contract_file

    enum :gender, { male: 0, female: 1 }
    enum :status, { not_settled: 0, settled: 1, temporarily_absent: 2, evicted: 3 }

    validates :last_name, presence: true, length: { maximum: 100 },
              format: { with: /\A[\p{L}\s\-]+\z/, message: :invalid_format }
    validates :first_name, presence: true, length: { maximum: 100 },
              format: { with: /\A[\p{L}\s\-]+\z/, message: :invalid_format }
    validates :middle_name, length: { maximum: 100 },
              format: { with: /\A[\p{L}\s\-]+\z/, message: :invalid_format },
              allow_blank: true
    validates :gender, inclusion: { in: genders.keys }
    validates :date_of_birth, presence: true
    validate :date_of_birth_not_in_future
    validates :phone, format: { with: /\A\+[1-9]\d{6,14}\z/, message: :invalid_phone },
              allow_blank: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid_email },
              allow_blank: true
    validates :student_ticket_number, presence: true
    validate :student_ticket_number_unique_among_kept
    validate :gender_immutable_when_settled, on: :update
    validate :photo_format_and_size
    validate :application_file_format_and_size
    validate :contract_file_format_and_size
    validate :document_number_required_when_file_attached

    scope :ordered, -> { order(:last_name, :first_name, :middle_name) }
    scope :search_by_name, ->(query) {
      where("last_name ILIKE :q OR first_name ILIKE :q OR middle_name ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
    }

    def full_name
      [ last_name, first_name, middle_name ].compact_blank.join(" ")
    end

    def do_create!
      track_event("dormitory.resident.created") { save! }
    end

    def do_update!(attrs)
      track_event("dormitory.resident.updated") { update!(attrs) }
    end

    def do_discard!
      if settled? || temporarily_absent?
        errors.add(:status, :cannot_delete_settled)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      track_event("dormitory.resident.discarded") { discard! }
    end

    # PURPOSE: Copies prepared application/contract documents (numbers and files) into the accommodation, only on the first settlement of the resident
    def copy_documents_to(accommodation)
      return unless accommodations.none?

      accommodation.application_number = application_number if accommodation.application_number.blank?
      accommodation.contract_number = contract_number if accommodation.contract_number.blank?
      accommodation.application_file.attach(application_file.blob) if application_file.attached? && !accommodation.application_file.attached?
      accommodation.contract_file.attach(contract_file.blob) if contract_file.attached? && !accommodation.contract_file.attached?
    end

    private

    def date_of_birth_not_in_future
      return unless date_of_birth

      if date_of_birth > Date.current
        errors.add(:date_of_birth, :future_date)
      end
    end

    def student_ticket_number_unique_among_kept
      return unless student_ticket_number

      scope = self.class.kept.where(student_ticket_number: student_ticket_number)
      scope = scope.where.not(id: id) if persisted?

      if scope.exists?
        existing = scope.first
        errors.add(:student_ticket_number, :taken, link: "/dormitory/residents/#{existing.id}")
      end
    end

    def gender_immutable_when_settled
      return unless gender_changed? && (settled? || temporarily_absent?)

      errors.add(:gender, :immutable_when_settled)
    end

    ACCEPTED_PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze
    MAX_PHOTO_SIZE = 5.megabytes

    ACCEPTED_DOCUMENT_TYPES = %w[application/pdf image/jpeg image/png application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document].freeze
    MAX_DOCUMENT_SIZE = 10.megabytes

    def photo_format_and_size
      return unless photo.attached?

      unless photo.content_type.in?(ACCEPTED_PHOTO_TYPES)
        errors.add(:photo, :invalid_format)
      end

      if photo.byte_size > MAX_PHOTO_SIZE
        errors.add(:photo, :too_large, max_size: "5 МБ")
      end
    end

    def validate_document(attachment, attribute_name)
      return unless attachment.attached?

      unless attachment.content_type.in?(ACCEPTED_DOCUMENT_TYPES)
        errors.add(attribute_name, :invalid_file_format)
      end

      if attachment.byte_size > MAX_DOCUMENT_SIZE
        errors.add(attribute_name, :file_too_large)
      end
    end

    def application_file_format_and_size
      validate_document(application_file, :application_file)
    end

    def contract_file_format_and_size
      validate_document(contract_file, :contract_file)
    end

    def document_number_required_when_file_attached
      errors.add(:application_number, :required_with_file) if application_file.attached? && application_number.blank?
      errors.add(:contract_number, :required_with_file) if contract_file.attached? && contract_number.blank?
    end
  end
end
