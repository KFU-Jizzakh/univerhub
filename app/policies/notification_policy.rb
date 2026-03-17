class NotificationPolicy < ApplicationPolicy
  # PURPOSE: Authorization rules for Notification — user sees own, can mark read
  # SPECIFICATION: SPEC-CORE-04
  def index?
    true
  end

  def mark_as_read?
    record.recipient_id == user.id
  end

  def mark_all_as_read?
    true
  end
end
