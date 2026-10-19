class User < ApplicationRecord
  include Discard::Model

  delegate :full_name, to: :profile, allow_nil: true

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  has_many :sessions, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_many :report_comments, class_name: "Reporting::ReportComment", dependent: :destroy
  has_many :commandant_buildings, class_name: "Dormitory::CommandantBuilding", dependent: :destroy
  has_many :assigned_buildings, -> { merge(Dormitory::CommandantBuilding.active) },
           through: :commandant_buildings, source: :building

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :with_role, ->(name) { joins(:user_roles).where(user_roles: { role_name: name }).distinct }
  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  after_discard :terminate_all_sessions

  def has_role?(role_name)
    effective_role == role_name
  end

  def assigned_role?(role_name)
    user_roles.exists?(role_name: role_name)
  end

  def active_role_context=(value)
    invalidate_effective_role
    @active_role_context = value
  end

  def active_role_context
    @active_role_context
  end

  # active_role_context is set per request from the session (see Authentication);
  # a stale context (role unassigned while the session lives) falls back to the
  # highest-privilege assigned role
  def effective_role
    return @effective_role if defined?(@effective_role)

    @effective_role =
      if active_role_context.present? && role_names.include?(active_role_context)
        active_role_context
      else
        role_names.min_by { |name| UserRole::ROLE_PRIORITY.index(name) || UserRole::ROLE_PRIORITY.size }
      end
  end

  def role_names
    user_roles.loaded? ? user_roles.map(&:role_name) : user_roles.pluck(:role_name)
  end

  def role_names=(names)
    names = Array(names).reject(&:blank?).uniq
    current = user_roles.pluck(:role_name)

    user_roles.where.not(role_name: names).find_each(&:do_destroy!)
    (names - current).each { |name| user_roles.build(role_name: name).do_create! }
    invalidate_effective_role
  end

  def add_role!(role_name)
    user_roles.build(role_name: role_name).do_create!
    invalidate_effective_role
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
    return false unless user.assigned_role?(role_name)
    with_role(role_name).kept.active.count <= 1
  end

  private

  def invalidate_effective_role
    remove_instance_variable(:@effective_role) if defined?(@effective_role)
  end

  def terminate_all_sessions
    sessions.destroy_all
  end
end
