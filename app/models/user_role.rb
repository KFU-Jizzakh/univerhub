class UserRole < ApplicationRecord
  # PURPOSE: Join table linking users to roles with uniqueness constraint, audit-trailed CRUD
  # SPECIFICATION: SPEC-CORE-02
  include Trackable

  belongs_to :user
  belongs_to :role

  validates :role_id, uniqueness: { scope: :user_id }

  def do_create!
    track_event("user_role.created") { save! }
  end

  def do_update!(attrs)
    track_event("user_role.updated") { update!(attrs) }
  end

  def do_destroy!
    track_event("user_role.destroyed") { destroy! }
  end
end
