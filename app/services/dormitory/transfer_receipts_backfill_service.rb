module Dormitory
  class TransferReceiptsBackfillService
    Result = Struct.new(:pairs_processed, :receipts_moved, :amounts_copied, :amounts_cleared,
                        :skipped_without_successor, keyword_init: true)

    def initialize(dry_run: false)
      @dry_run = dry_run
    end

    def call
      stats = Result.new(pairs_processed: 0, receipts_moved: 0, amounts_copied: 0, amounts_cleared: 0,
                         skipped_without_successor: 0)

      candidates.find_each do |old_acc|
        successor = successor_for(old_acc)
        if successor.nil?
          stats.skipped_without_successor += 1
          next
        end

        stats.pairs_processed += 1
        if @dry_run
          stats.receipts_moved += Dormitory::Receipt.with_discarded.where(accommodation_id: old_acc.id).count
          stats.amounts_copied += 1 if amount_inheritable?(old_acc, successor)
          stats.amounts_cleared += 1 if amount_clearable?(old_acc)
        else
          moved, amount_copied, amount_cleared = migrate_pair!(old_acc, successor)
          stats.receipts_moved += moved
          stats.amounts_copied += amount_copied
          stats.amounts_cleared += amount_cleared
        end
      end

      stats
    end

    private

    # origins with receipts to move, plus already-backfilled origins that still keep
    # a phantom required_amount after their payments moved to the successor
    def candidates
      receipt_acc_ids = Dormitory::Receipt.with_discarded.select(:accommodation_id)
      Dormitory::Accommodation.with_discarded
        .where(status: :completed, eviction_reason: %w[transfer repair])
        .where("dormitory_accommodations.required_amount > 0 OR dormitory_accommodations.id IN (?)", receipt_acc_ids)
        .order(:id)
    end

    def successor_for(old_acc)
      return nil unless old_acc.actual_end_date

      Dormitory::Accommodation.kept
        .where(resident_id: old_acc.resident_id)
        .where.not(id: old_acc.id)
        .where(start_date: old_acc.actual_end_date)
        .order(start_date: :asc, id: :asc)
        .first
    end

    def migrate_pair!(old_acc, successor)
      ActiveRecord::Base.transaction do
        moved = Dormitory::Receipt.with_discarded.where(accommodation_id: old_acc.id)
          .update_all(accommodation_id: successor.id, updated_at: Time.current)
        amount_copied = 0
        if amount_inheritable?(old_acc, successor)
          successor.update_columns(required_amount: old_acc.required_amount)
          amount_copied = 1
        end
        amount_cleared = clear_source_amount!(old_acc)

        OutboxEvent.create!(
          actor: nil,
          action: "dormitory.receipts.transferred",
          record: old_acc,
          payload: { to_accommodation_id: successor.id, count: moved, via: :backfill }
        )

        [ moved, amount_copied, amount_cleared ]
      end
    end

    def amount_inheritable?(old_acc, successor)
      old_acc.required_amount.positive? && successor.required_amount.zero?
    end

    def amount_clearable?(old_acc)
      old_acc.required_amount.positive?
    end

    # the obligation fully lives on the successor — the origin must not keep a phantom required_amount
    def clear_source_amount!(old_acc)
      return 0 unless amount_clearable?(old_acc)

      old_acc.update_columns(required_amount: 0)
      1
    end
  end
end
