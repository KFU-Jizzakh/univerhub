class AddMaxGradeToReportTemplateItems < ActiveRecord::Migration[8.1]
  def change
    add_column :report_template_items, :max_grade, :integer
  end
end
