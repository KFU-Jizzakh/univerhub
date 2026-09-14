namespace :dormitory do
  desc "Backfill: move receipts from completed transfer-origin accommodations to their successors. DRY_RUN=1 to preview only"
  task backfill_transfer_receipts: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])

    puts dry_run ? "=== DRY RUN: no changes will be made ===" : "=== Applying transfer receipts backfill ==="

    stats = Dormitory::TransferReceiptsBackfillService.new(dry_run: dry_run).call

    puts format("%-35s %d", "Pairs processed", stats.pairs_processed)
    puts format("%-35s %d", "Receipts moved", stats.receipts_moved)
    puts format("%-35s %d", "Required amounts copied", stats.amounts_copied)
    puts format("%-35s %d", "Skipped (no successor found)", stats.skipped_without_successor)
    puts dry_run ? "=== DRY RUN finished: rerun without DRY_RUN to apply ===" : "=== Done ==="
  end
end
