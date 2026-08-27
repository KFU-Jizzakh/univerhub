module PreservesAttachmentChanges
  # PURPOSE: Keeps pending Active Storage uploads alive across a pessimistic row lock, which reloads the record and would otherwise silently discard them
  # SPECIFICATION: SPEC-DORM-04, SPEC-DORM-12
  extend ActiveSupport::Concern

  # PURPOSE: Locks the row exactly like lock!, then restores the attachment changes the reload has wiped, so deferred uploads still run at commit
  # SPECIFICATION: SPEC-DORM-04, SPEC-DORM-12
  def lock_preserving_attachment_changes!
    pending = attachment_changes
    lock!
    @attachment_changes = pending if pending.present?
  end
end
