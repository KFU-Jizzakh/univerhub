class Notification < ApplicationRecord
  # PURPOSE: In-app notification with polymorphic notifiable record, read/unread state, and recipient scoping
  # SPECIFICATION: SPEC-CORE-04
  belongs_to :recipient, class_name: "User"
  belongs_to :notifiable, polymorphic: true

  validates :action, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current)
  end
end
