module Reporting
  class ReportComment < ApplicationRecord
    # PURPOSE: Comment on a report by any participant in the reporting workflow
    # SPECIFICATION: SPEC-REPT-01
    include Trackable

    belongs_to :report, class_name: "Reporting::Report"
    belongs_to :user

    validates :body, presence: true, length: { maximum: 5000 }

    scope :recent, -> { order(created_at: :desc) }

    def do_create!
      track_event("reporting.report_comment.created") { save! }
    end

    def do_update!(attrs)
      track_event("reporting.report_comment.updated") { update!(attrs) }
    end

    def do_destroy!
      track_event("reporting.report_comment.destroyed") { destroy! }
    end
  end
end
