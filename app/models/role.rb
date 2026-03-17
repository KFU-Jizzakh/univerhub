class Role < ApplicationRecord
  # PURPOSE: Predefined role with name from NAMES constant, many-to-many users via user_roles, audit-trailed CRUD
  # SPECIFICATION: SPEC-CORE-02
  include Trackable

  NAMES = %w[admin reporting.manager reporting.reporter reporting.reviewer reporting.visitor supervisor reporting.admin dormitory.admin dormitory.commandant].freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }

  def do_create!
    track_event("role.created") { save! }
  end

  def do_update!(attrs)
    track_event("role.updated") { update!(attrs) }
  end

  def do_destroy!
    track_event("role.destroyed") { destroy! }
  end
end
