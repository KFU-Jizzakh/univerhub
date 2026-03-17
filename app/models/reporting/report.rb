module Reporting
  class Report < ApplicationRecord
    # PURPOSE: Full report lifecycle with AASM state machine (draft→new→in_progress→in_review→accepted/rejected/reopened), items, grading, comments, and deadline tracking
    # SPECIFICATION: SPEC-REPT-01
    include AASM
    include Discard::Model
    include Trackable

    belongs_to :creator, class_name: "User"
    belongs_to :reporter, class_name: "User", optional: true
    belongs_to :reviewer, class_name: "User", optional: true
    belongs_to :report_template, class_name: "Reporting::ReportTemplate", optional: true
    has_many :report_items, class_name: "Reporting::ReportItem", dependent: :destroy, foreign_key: "report_id"
    has_one_attached :pdf_file
    has_many :comments, class_name: "Reporting::ReportComment", dependent: :destroy, foreign_key: "report_id"

    validates :name, presence: true
    validates :reporter_id, :reviewer_id, :deadline, presence: true, unless: :draft?
    validates :rejection_reason, length: { maximum: 2000 }
    validates :rejection_reason, presence: true, if: :rejected?
    validate :reporter_and_reviewer_must_differ

    scope :search_by_name, ->(q) { where("name ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
    scope :overdue, -> { where("deadline < ? AND status NOT IN (?)", Time.current, %w[accepted archived]) }
    scope :deadline_soon, ->(days = 3) { where("deadline BETWEEN ? AND ? AND status NOT IN (?)", Time.current, days.days.from_now, %w[accepted archived]) }

    aasm column: :status, whiny_transitions: true, whiny_persistence: true do
      state :draft, initial: true
      state :new
      state :in_progress
      state :in_review
      state :rejected
      state :accepted
      state :reopened

      event :publish do
        transitions from: :draft, to: :new, if: :has_items?
      end

      event :take_in_progress do
        transitions from: [ :new, :reopened ], to: :in_progress
      end

      event :submit do
        transitions from: :in_progress, to: :in_review, if: :all_attachments_present?
        after do
          update!(submitted_at: Time.current)
        end
      end

      event :reject do
        transitions from: :in_review, to: :rejected
        after do
          update!(reviewed_at: Time.current)
        end
      end

      event :accept do
        transitions from: :in_review, to: :accepted, if: :all_items_graded?
        before do
          self.total_grade = report_items.sum(:grade)
        end
        after do
          update!(reviewed_at: Time.current)
        end
      end

      event :reopen do
        transitions from: :rejected, to: :reopened
      end
    end

    def editable?
      draft? || in_progress? || rejected? || reopened?
    end

    def has_items?
      report_items.any?
    end

    def missing_attachment_items
      report_items.select { |item| item.attachments_required? && !item.attachments.attached? }
    end

    def all_attachments_present?
      missing_attachment_items.empty?
    end

    def all_items_graded?
      report_items.any? && report_items.where(grade: nil).none?
    end

    def overdue?
      deadline.present? && deadline < Time.current && !accepted?
    end

    def deadline_soon?(days = 3)
      deadline.present? && deadline > Time.current && deadline <= days.days.from_now && !accepted?
    end

    def pdf_cache_key
      template_digest = if report_template&.pdf_template_path
        Digest::MD5.file(report_template.pdf_template_path).hexdigest
      else
        "none"
      end
      items_hash = report_items.order(:id).pluck(:updated_at, :grade, :content).map(&:to_s).join
      Digest::MD5.hexdigest("#{updated_at}-#{status}-#{total_grade}-#{items_hash}-#{template_digest}")
    end

    def do_create!
      track_event("reporting.report.created", { name: name }) { save! }
    end

    def do_update!(attrs)
      track_event("reporting.report.updated", { name: name }) { update!(attrs) }
    end

    def do_publish!
      track_event("reporting.report.published", { reporter_id: reporter_id, reviewer_id: reviewer_id, deadline: deadline }) do
        publish!
        notify(reporter, "reporting.report.assigned") if reporter
      end
    end

    def do_take_in_progress!
      track_event("reporting.report.taken_in_progress") { take_in_progress! }
    end

    def do_submit!
      track_event("reporting.report.submitted") do
        submit!
        notify(reviewer, "reporting.report.submitted") if reviewer
      end
    end

    def do_reject!(reason)
      if reason.blank?
        errors.add(:rejection_reason, :blank)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      self.rejection_reason = reason
      unless valid?
        raise ActiveRecord::RecordInvalid.new(self)
      end

      track_event("reporting.report.rejected", { rejection_reason: reason }) do
        reject!
        notify(reporter, "reporting.report.rejected") if reporter
      end
    end

    def do_accept!
      track_event("reporting.report.accepted", -> { { total_grade: total_grade } }) do
        accept!
        notify(reporter, "reporting.report.accepted") if reporter
      end
    end

    def do_reopen!
      track_event("reporting.report.reopened") do
        reopen!
        notify(reviewer, "reporting.report.reopened") if reviewer
      end
    end

    def do_discard!
      track_event("reporting.report.discarded", { name: name }) { discard! }
    end

    private

    def notify(recipient, action)
      Notification.create!(recipient: recipient, notifiable: self, action: action)
    end

    def reporter_and_reviewer_must_differ
      if reporter_id.present? && reviewer_id.present? && reporter_id == reviewer_id
        errors.add(:reviewer_id, :cannot_be_same_as_reporter)
      end
    end
  end
end
