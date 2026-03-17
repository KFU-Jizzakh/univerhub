module Admin
  class UserPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for admin user management — super-admin full access, scoped admins manage module users only
    # SPECIFICATION: SPEC-CORE-02, SPEC-CORE-03
    MODULE_ROLES = {
      "reporting.admin" => %w[reporting.manager reporting.reporter reporting.reviewer reporting.visitor reporting.admin],
      "dormitory.admin" => %w[dormitory.admin dormitory.commandant]
    }.freeze

    PROTECTED_ROLES = %w[dormitory.admin].freeze

    def index?
      user.has_role?("admin") || module_scoped_admin?
    end

    def show?
      user.has_role?("admin") || module_scoped_admin?
    end

    def new?
      user.has_role?("admin") || module_scoped_admin?
    end

    def create?
      user.has_role?("admin") || module_scoped_admin?
    end

    def edit?
      user.has_role?("admin") || module_scoped_admin?
    end

    def update?
      user.has_role?("admin") || module_scoped_admin?
    end

    def destroy?
      return false unless user.has_role?("admin")
      return false if record == user
      !last_active_in_protected_role?
    end

    def reset_password?
      user.has_role?("admin") && record != user
    end

    def activate?
      if user.has_role?("admin")
        record != user
      elsif module_scoped_admin?
        record != user && user_in_same_module?(record)
      else
        false
      end
    end

    def deactivate?
      if user.has_role?("admin")
        return false if record == user
        return false if last_active_in_protected_role?
        true
      elsif module_scoped_admin?
        record != user && user_in_same_module?(record)
      else
        false
      end
    end

    private

    def last_active_in_protected_role?
      PROTECTED_ROLES.any? { |role_name| User.last_active_with_role?(record, role_name) }
    end

    def module_scoped_admin?
      MODULE_ROLES.keys.any? { |admin_role| user.has_role?(admin_role) }
    end

    def user_in_same_module?(user_record)
      MODULE_ROLES.each do |admin_role, module_roles|
        next unless user.has_role?(admin_role)
        return false if user_record.roles.empty?
        return user_record.roles.pluck(:name).all? { |n| module_roles.include?(n) }
      end
      false
    end
  end
end
