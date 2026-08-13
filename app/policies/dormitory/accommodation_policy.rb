module Dormitory
  class AccommodationPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Accommodation — admin/dormitory.admin full access, commandant scoped to assigned buildings, registrar read-only
    # SPECIFICATION: SPEC-DORM-04
    def index?
      admin_or_dormitory_admin? || commandant? || registrar?
    end

    def show?
      admin_or_dormitory_admin? || commandant_with_room_access? || registrar?
    end

    def new?
      admin_or_dormitory_admin? || commandant?
    end

    def create?
      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    def edit?
      update?
    end

    def update?
      return admin_or_dormitory_admin? if record.is_a?(Dormitory::Accommodation) && record.pending?

      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    # PURPOSE: An admin or the registrar can confirm a pending accommodation
    # SPECIFICATION: SPEC-DORM-12
    def confirm?
      admin_or_dormitory_admin? || registrar?
    end

    # PURPOSE: Only admin/dormitory.admin can reject a pending accommodation
    # SPECIFICATION: SPEC-DORM-12
    def reject?
      admin_or_dormitory_admin?
    end

    def force?
      admin_or_dormitory_admin?
    end

    def new_transfer?
      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    def transfer?
      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    def new_eviction?
      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    def evict?
      admin_or_dormitory_admin? || commandant_with_room_access?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.kept
        elsif user.has_role?("dormitory.registrar")
          scope.kept
        elsif user.has_role?("dormitory.commandant")
          scope.kept.joins(:room).where(dormitory_rooms: { building_id: user.assigned_building_ids })
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

    def registrar?
      user.has_role?("dormitory.registrar")
    end

    def commandant_with_room_access?
      return false unless commandant?
      return true unless record.is_a?(Dormitory::Accommodation)
      return false unless record.room_id.present?

      record.room.building_id.in?(user.assigned_building_ids)
    end
  end
end
