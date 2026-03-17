class CreateReportItems < ActiveRecord::Migration[8.1]
  def change
    create_table :report_items do |t|
      t.references :report, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :content
      t.boolean :attachments_required, default: false, null: false
      t.integer :max_grade
      t.integer :grade
      t.text :grade_comment

      t.timestamps
    end
  end
end
