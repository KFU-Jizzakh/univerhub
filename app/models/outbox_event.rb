class OutboxEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :record, polymorphic: true, optional: true

  validates :action, presence: true
end
