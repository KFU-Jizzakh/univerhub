module Reporting
  class ReportsController < ApplicationController
    before_action :set_report, only: [ :show, :edit, :update, :destroy, :publish, :take_in_progress, :submit, :accept, :reject, :reopen, :pdf, :regenerate_pdf ]

    def index
      @filter_reporters = User.with_role("reporting.reporter").includes(:profile)
      @reports = policy_scope(Reporting::Report).includes(:reporter, :reviewer).order(created_at: :desc)
      @reports = @reports.where(status: params[:status]) if params[:status].present?
      @reports = @reports.search_by_name(params[:q]) if params[:q].present?
      @reports = @reports.where(reporter_id: params[:reporter_id]) if params[:reporter_id].present?
      @reports = @reports.where(reviewer_id: params[:reviewer_id]) if params[:reviewer_id].present?
      if (from = parse_date(params[:deadline_from]))
        @reports = @reports.where("deadline >= ?", from)
      end
      if (to = parse_date(params[:deadline_to]))
        @reports = @reports.where("deadline <= ?", to)
      end
      @pagy, @reports = pagy(:offset, @reports)
      @status_counts = policy_scope(Reporting::Report).group(:status).count
    end

    def show
      authorize @report
      @report_items = @report.report_items
      @comments = @report.comments.recent.includes(:user)
      @events = OutboxEvent.where(record: @report).includes(:actor).order(created_at: :desc)
      @comment = Reporting::ReportComment.new
    end

    def new
      @report = Reporting::Report.new
      authorize @report
      load_form_collections
    end

    def create
      @report = Reporting::Report.new(report_params)
      @report.creator = Current.user
      authorize @report

      template_id = params[:reporting_report][:report_template_id]
      template = Reporting::ReportTemplate.available.find_by(id: template_id) if template_id.present?

      if template_id.present? && template.nil?
        @report.errors.add(:report_template_id, :not_available)
        load_form_collections
        return render :new, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        @report.report_template_id = template&.id
        @report.do_create!
        copy_items_from(template) if template
      end

      redirect_to @report, notice: t("reporting.reports.created")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Report creation failed for user #{Current.user.id}: #{e.message}"
      load_form_collections
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @report
      load_form_collections
    end

    def update
      authorize @report

      @report.do_update!(report_params)
      redirect_to @report, notice: t("reporting.reports.updated")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report update failed for report #{@report.id}: #{e.message}"
      load_form_collections
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @report
      @report.do_discard!
      redirect_to reporting_reports_path, notice: t("reporting.reports.destroyed")
    end

    def publish
      authorize @report
      @report.do_publish!
      redirect_to @report, notice: t("reporting.reports.published")
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report publish failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: state_error_alert(e, :cannot_publish)
    end

    def take_in_progress
      authorize @report
      @report.do_take_in_progress!
      redirect_to @report, notice: t("reporting.reports.taken_in_progress")
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report take_in_progress failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: state_error_alert(e, :cannot_take_in_progress)
    end

    def submit
      authorize @report
      @report.do_submit!
      redirect_to @report, notice: t("reporting.reports.submitted")
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report submit failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: state_error_alert(e, :cannot_submit)
    end

    def accept
      authorize @report
      @report.do_accept!
      redirect_to @report, notice: t("reporting.reports.accepted")
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      redirect_to @report, alert: state_error_alert(e, :cannot_accept)
    end

    def reject
      authorize @report
      reason = reject_params[:rejection_reason]
      @report.do_reject!(reason)
      redirect_to @report, notice: t("reporting.reports.rejected")
    rescue AASM::InvalidTransition => e
      Rails.logger.warn "Report reject failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: state_error_alert(e, :cannot_reject)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report reject failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: t("reporting.reports.errors.cannot_reject")
    end

    def reopen
      authorize @report
      @report.do_reopen!
      redirect_to @report, notice: t("reporting.reports.reopened")
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Report reopen failed for report #{@report.id}: #{e.message}"
      redirect_to @report, alert: state_error_alert(e, :cannot_reopen)
    end

    def pdf
      authorize @report
      pdf_file = Reporting::PdfGenerator.new(@report).call
      send_data pdf_file.download,
        filename: pdf_file.filename.to_s,
        type: "application/pdf",
        disposition: "inline"
    rescue Pundit::NotAuthorizedError
      raise
    rescue StandardError => e
      Rails.logger.error("PDF generation failed: #{e.message}")
      redirect_to @report, alert: t("reporting.reports.errors.pdf_generation_failed")
    end

    def regenerate_pdf
      authorize @report
      Reporting::PdfGenerator.new(@report, force: true).call
      redirect_to pdf_reporting_report_path(@report), notice: t("reporting.reports.pdf_regenerated")
    rescue Pundit::NotAuthorizedError
      raise
    rescue StandardError => e
      Rails.logger.error("PDF regeneration failed: #{e.message}")
      redirect_to @report, alert: t("reporting.reports.errors.pdf_generation_failed")
    end

    private

    def set_report
      @report = Reporting::Report.find(params[:id])
    end

    def report_params
      params.require(:reporting_report).permit(:name, :description, :deadline, :reporter_id, :reviewer_id)
    end

    def reject_params
      params.permit(:rejection_reason)
    end

    def load_form_collections
      @templates = Reporting::ReportTemplate.available
      @reporters = User.with_role("reporting.reporter")
      @reviewers = User.with_role("reporting.reviewer")
    end

    def parse_date(raw)
      Date.parse(raw) if raw.present?
    rescue ArgumentError
      nil
    end

    def copy_items_from(template)
      template.items.ordered.each do |item|
        @report.report_items.create!(
          name: item.name,
          description: item.description,
          attachments_required: item.attachments_required,
          max_grade: item.max_grade
        )
      end
    end

    def state_error_alert(exception, fallback_key)
      if exception.is_a?(ActiveRecord::RecordInvalid)
        exception.record.errors.full_messages.join(", ")
      else
        t("reporting.reports.errors.#{fallback_key}")
      end
    end
  end
end
