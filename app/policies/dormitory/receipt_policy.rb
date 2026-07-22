module Dormitory
  class ReceiptPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Receipt — admin/dormitory.admin full access, commandant scoped to assigned buildings
    # SPECIFICATION: SPEC-DORM-09

    def new?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    def create?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    def edit?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    def update?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    def destroy?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.kept
        elsif user.has_role?("dormitory.commandant")
          scope.kept.joins(accommodation: :room).where(dormitory_rooms: { building_id: user.assigned_building_ids })
        else
          scope.none
        end
      end
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def commandant?
      user.has_role?("dormitory.commandant")
    end

    def commandant_with_access?
      return false unless commandant?
      return user.assigned_building_ids.any? unless record.is_a?(Dormitory::Receipt)
      return false unless record.accommodation&.room_id.present?

      record.accommodation.room.building_id.in?(user.assigned_building_ids)
    end
  end
end
