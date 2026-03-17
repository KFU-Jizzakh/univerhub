class CreateReportTemplateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :report_template_items do |t|
      t.references :report_template, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :position, default: 0, null: false
      t.boolean :attachments_required, default: false, null: false

      t.timestamps
    end
  end
end
