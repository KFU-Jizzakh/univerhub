module Reporting
  class ReportItem < ApplicationRecord
    # PURPOSE: Report item with content, attachments, grading, and graded-by tracking
    # SPECIFICATION: SPEC-REPT-01
    include Trackable


    belongs_to :report, class_name: "Reporting::Report"
    has_many_attached :attachments

    validates :name, presence: true
    validates :grade, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :max_grade }, allow_nil: true, if: :max_grade

    def do_update_content!(attrs)
      track_event("reporting.report_item.updated", { item: name }) { update(attrs) }
    end

    def do_grade!(attrs)
      track_event("reporting.report_item.graded", { item: name, grade: attrs[:grade] }) { update(attrs) }
    end
  end
end
