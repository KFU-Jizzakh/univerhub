class MigratePaymentReceiptsToReceipts < ActiveRecord::Migration[8.1]
  # PURPOSE: Migrate legacy payment_receipt attachments on Accommodation into proper Receipt records
  # SPECIFICATION: SPEC-DORM-09

  def up
    payment_receipts = ActiveStorage::Attachment.where(
      record_type: "Dormitory::Accommodation",
      name: "payment_receipt"
    ).includes(:blob)

    payment_receipts.find_each do |payment_receipt|
      acc = Dormitory::Accommodation.find_by(id: payment_receipt.record_id)
      next unless acc

      existing_ids = Dormitory::Receipt.where(accommodation_id: acc.id).pluck(:id)
      next if existing_ids.any? &&
        ActiveStorage::Attachment.where(
          record_type: "Dormitory::Receipt", record_id: existing_ids
        ).exists?

      receipt = Dormitory::Receipt.new(
        accommodation_id: acc.id,
        amount: acc.required_amount.to_i.positive? ? acc.required_amount : 1,
        paid_at: acc.start_date || acc.created_at.to_date,
        comment: "Мигрировано из payment_receipt"
      )
      receipt.attachment.attach(payment_receipt.blob)
      receipt.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
