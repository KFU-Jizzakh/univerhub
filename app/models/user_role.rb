class UserRole < ApplicationRecord
  # PURPOSE: User-role assignment storing the role name as a string (roles are defined in code, not the database), audit-trailed CRUD
  # SPECIFICATION: SPEC-CORE-02
  include Trackable

  NAMES = %w[admin reporting.manager reporting.reporter reporting.reviewer reporting.visitor supervisor reporting.admin dormitory.admin dormitory.commandant dormitory.registrar].freeze

  MODULE_ROLES = {
    "reporting.admin" => %w[reporting.manager reporting.reporter reporting.reviewer reporting.visitor reporting.admin],
    "dormitory.admin" => %w[dormitory.admin dormitory.commandant dormitory.registrar]
  }.freeze

  belongs_to :user

  validates :role_name, presence: true, inclusion: { in: NAMES }, uniqueness: { scope: :user_id }

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
