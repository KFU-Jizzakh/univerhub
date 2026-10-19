class NotificationPolicy < ApplicationPolicy
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
