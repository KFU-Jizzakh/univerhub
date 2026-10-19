# lock! reloads the record and silently discards pending Active Storage uploads;
# restoring attachment_changes keeps deferred uploads running at commit.
module PreservesAttachmentChanges
  extend ActiveSupport::Concern

  def lock_preserving_attachment_changes!
    pending = attachment_changes
    lock!
    @attachment_changes = pending if pending.present?
  end
end
