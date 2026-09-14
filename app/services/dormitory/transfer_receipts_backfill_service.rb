module Dormitory
  # PURPOSE: One-off backfill that moves receipts from completed transfer/repair-origin accommodations to their exact-day successor accommodations and inherits the required amount
  # SPECIFICATION: SPEC-DORM-04
  class TransferReceiptsBackfillService
    Result = Struct.new(:pairs_processed, :receipts_moved, :amounts_copied, :skipped_without_successor, keyword_init: true)

    def initialize(dry_run: false)
      @dry_run = dry_run
    end

    def call
      stats = Result.new(pairs_processed: 0, receipts_moved: 0, amounts_copied: 0, skipped_without_successor: 0)

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
        else
          moved, amount_copied = migrate_pair!(old_acc, successor)
          stats.receipts_moved += moved
          stats.amounts_copied += amount_copied
        end
      end

      stats
    end

    private

    # PURPOSE: Returns completed transfer and repair origins (including discarded ones) that still have receipts
    # SPECIFICATION: SPEC-DORM-04
    def candidates
      receipt_acc_ids = Dormitory::Receipt.with_discarded.select(:accommodation_id)
      Dormitory::Accommodation.with_discarded
        .where(status: :completed, eviction_reason: %w[transfer repair])
        .where(id: receipt_acc_ids)
        .order(:id)
    end

    # PURPOSE: Returns the resident's earliest kept accommodation that starts exactly on the origin's actual end date (the transfer day)
    # SPECIFICATION: SPEC-DORM-04
    def successor_for(old_acc)
      return nil unless old_acc.actual_end_date

      Dormitory::Accommodation.kept
        .where(resident_id: old_acc.resident_id)
        .where.not(id: old_acc.id)
        .where(start_date: old_acc.actual_end_date)
        .order(start_date: :asc, id: :asc)
        .first
    end

    # PURPOSE: Reassigns all receipts (including discarded) to the successor, copies the required amount when the successor has none, and records an aggregate audit event
    # SPECIFICATION: SPEC-DORM-04
    def migrate_pair!(old_acc, successor)
      ActiveRecord::Base.transaction do
        moved = Dormitory::Receipt.with_discarded.where(accommodation_id: old_acc.id)
          .update_all(accommodation_id: successor.id, updated_at: Time.current)
        amount_copied = 0
        if amount_inheritable?(old_acc, successor)
          successor.update_columns(required_amount: old_acc.required_amount)
          amount_copied = 1
        end

        OutboxEvent.create!(
          actor: nil,
          action: "dormitory.receipts.transferred",
          record: old_acc,
          payload: { to_accommodation_id: successor.id, count: moved, via: :backfill }
        )

        [ moved, amount_copied ]
      end
    end

    def amount_inheritable?(old_acc, successor)
      old_acc.required_amount.positive? && successor.required_amount.zero?
    end
  end
end
