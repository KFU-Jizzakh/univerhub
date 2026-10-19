module Reporting
  class ReportTemplateItem < ApplicationRecord
    belongs_to :report_template, class_name: "Reporting::ReportTemplate"

    validates :name, presence: true
    validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :ordered, -> { order(:position) }
  end
end
