class CreateReportTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :report_templates do |t|
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.references :creator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
