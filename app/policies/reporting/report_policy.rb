module Reporting
  class ReportPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Report — role-based lifecycle access (manager creates, reporter submits, reviewer grades)
    # SPECIFICATION: SPEC-REPT-01
    def index?
      true
    end

    def show?
      return true if user.has_role?("admin") || user.has_role?("reporting.admin") ||
        record.creator_id == user.id ||
        record.reporter_id == user.id ||
        record.reviewer_id == user.id ||
        user.has_role?("supervisor")

      user.has_role?("reporting.visitor") && !record.draft?
    end

    def create?
      user.has_role?("reporting.manager") || user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def update?
      (user.has_role?("reporting.manager") && record.draft? && record.creator_id == user.id) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def update_items?
      (user.has_role?("reporting.reporter") && record.editable? && record.reporter_id == user.id) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def destroy?
      (user.has_role?("reporting.manager") && record.draft? && record.creator_id == user.id) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def publish?
      (user.has_role?("reporting.manager") && record.draft? && record.creator_id == user.id) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def submit?
      (record.reporter_id == user.id && record.in_progress?) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def take_in_progress?
      (record.reporter_id == user.id && (record.new? || record.reopened?)) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def grade?
      (record.reviewer_id == user.id && record.in_review?) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def accept?
      (record.reviewer_id == user.id && record.in_review? && record.all_items_graded?) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def reject?
      (record.reviewer_id == user.id && record.in_review?) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def reopen?
      (record.reporter_id == user.id && record.rejected?) ||
        user.has_role?("admin") || user.has_role?("reporting.admin")
    end

    def access_comments?
      user.has_role?("admin") || user.has_role?("reporting.admin") ||
        user.has_role?("reporting.manager") ||
        user.has_role?("reporting.reporter") ||
        user.has_role?("reporting.reviewer") ||
        user.has_role?("supervisor")
    end

    def view_history?
      access_comments?
    end

    def pdf?
      show?
    end

    def regenerate_pdf?
      user.has_role?("admin") || user.has_role?("reporting.admin") ||
        user.has_role?("reporting.manager") ||
        record.creator_id == user.id
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("supervisor") || user.has_role?("reporting.admin")
          scope.all
        elsif user.has_role?("reporting.visitor")
          scope.where.not(status: :draft)
        elsif user.has_role?("reporting.manager")
          scope.where(creator: user)
        elsif user.has_role?("reporting.reviewer")
          scope.where(reviewer: user)
        elsif user.has_role?("reporting.reporter")
          scope.where(reporter: user)
        else
          scope.none
        end
      end
    end
  end
end
