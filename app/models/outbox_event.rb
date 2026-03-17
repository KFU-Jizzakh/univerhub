class OutboxEvent < ApplicationRecord
  # PURPOSE: Audit log event created by Trackable concern, with polymorphic record, actor, action, and payload
  # SPECIFICATION: SPEC-CORE-04
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :record, polymorphic: true, optional: true

  validates :action, presence: true
end
