class User < ApplicationRecord
  # PURPOSE: User entity with email/password authentication, role assignment, account activation/deactivation, soft-delete, and profile delegation
  # SPECIFICATION: SPEC-CORE-01, SPEC-CORE-02
  include Discard::Model

  delegate :full_name, to: :profile, allow_nil: true

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  has_many :sessions, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_many :report_comments, class_name: "Reporting::ReportComment", dependent: :destroy
  has_many :commandant_buildings, class_name: "Dormitory::CommandantBuilding", dependent: :destroy
  has_many :assigned_buildings, -> { merge(Dormitory::CommandantBuilding.active) },
           through: :commandant_buildings, source: :building

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :with_role, ->(name) { joins(:roles).where(roles: { name: name }).distinct }
  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  after_discard :terminate_all_sessions

  def has_role?(role_name)
    roles.exists?(name: role_name)
  end

  def active?
    deactivated_at.nil?
  end

  def deactivated?
    deactivated_at.present?
  end

  def deactivate!
    return if deactivated?
    update!(deactivated_at: Time.current)
  end

  def activate!
    return if active?
    update!(deactivated_at: nil)
  end

  def self.last_active_with_role?(user, role_name)
    return false unless user.has_role?(role_name)
    with_role(role_name).kept.active.count <= 1
  end

  private

  def terminate_all_sessions
    sessions.destroy_all
  end
end
