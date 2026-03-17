class HomeController < ApplicationController
  DORMITORY_RECORD_TYPES = %w[
    Dormitory::Resident
    Dormitory::Accommodation
    Dormitory::Room
    Dormitory::Building
  ].freeze

  def index
    authorize :dashboard
    @user = Current.user
    @unread_notifications = @user.notifications.unread.count
    @user_roles = @user.roles.pluck(:name)

    if @user.has_role?("reporting.manager")
      manager_reports = Reporting::Report.where(creator: @user)
      @total_reports_count = manager_reports.count
      @published_templates_count = Reporting::ReportTemplate.where(creator: @user).published.count
      @draft_reports = manager_reports.where(status: "draft").limit(5)
      @overdue_reports = manager_reports.overdue.limit(5)
      @status_counts = manager_reports.group(:status).count
    end

    if @user.has_role?("reporting.reporter")
      reporter_reports = Reporting::Report.where(reporter: @user)
      @assigned_reports = reporter_reports.where(status: %w[new in_progress rejected reopened]).limit(10)
      @completed_reports_count = reporter_reports.where(status: "accepted").count
      @overdue_reports ||= reporter_reports.overdue.limit(5)
    end

    if @user.has_role?("reporting.reviewer")
      reviewer_reports = Reporting::Report.where(reviewer: @user)
      @review_reports = reviewer_reports.where(status: "in_review").limit(10)
      @reviewed_count = reviewer_reports.where(status: "accepted").count
    end

    if @user.has_role?("reporting.admin")
      admin_reports = Reporting::Report.all
      @total_reports_count = admin_reports.count
      @published_templates_count = Reporting::ReportTemplate.published.count
      @overdue_reports ||= admin_reports.overdue.limit(5)
      @status_counts = admin_reports.group(:status).count
    end

    if @user.has_role?("supervisor") || @user.has_role?("admin")
      @recent_events = OutboxEvent.order(created_at: :desc).includes(:actor).limit(10)
      if @user.has_role?("admin")
        @total_users_count = User.count
        @status_counts ||= Reporting::Report.group(:status).count
      end
    end

    # Restrict activity feed for scoped admins (e.g., reporting.admin, dormitory.admin)
    scoped_admin_prefixes = @user.roles.where("name LIKE '%.admin'").pluck(:name).map { |r| r.split(".").first }.uniq
    if scoped_admin_prefixes.any? && !@user.has_role?("admin")
      @recent_events = OutboxEvent.order(created_at: :desc).includes(:actor).limit(10)
        .where(scoped_admin_prefixes.map { "action LIKE ?" }.join(" OR "), *scoped_admin_prefixes.map { |p| "#{p}.%" })
    end
  end
end
