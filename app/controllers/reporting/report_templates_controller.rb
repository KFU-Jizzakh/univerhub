module Reporting
  class ReportTemplatesController < ApplicationController
    before_action :set_report_template, only: [ :show, :edit, :update, :destroy, :publish, :archive ]

    def index
      @report_templates = policy_scope(Reporting::ReportTemplate).order(created_at: :desc)
      @pagy, @report_templates = pagy(:offset, @report_templates)
    end

    def show
      authorize @report_template
      @items = @report_template.items.ordered
    end

    def new
      @report_template = Reporting::ReportTemplate.new
      authorize @report_template
    end

    def create
      @report_template = Reporting::ReportTemplate.new(report_template_params)
      @report_template.creator = Current.user
      authorize @report_template

      if @report_template.save
        redirect_to @report_template, notice: t("reporting.report_templates.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @report_template
    end

    def update
      authorize @report_template

      if @report_template.update(report_template_params)
        redirect_to @report_template, notice: t("reporting.report_templates.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @report_template
      @report_template.destroy!
      redirect_to reporting_report_templates_path, notice: t("reporting.report_templates.destroyed")
    end

    def publish
      authorize @report_template
      @report_template.do_publish!
      redirect_to @report_template, notice: t("reporting.report_templates.published")
    rescue AASM::InvalidTransition => e
      Rails.logger.warn "Report template publish failed for template #{@report_template.id}: #{e.message}"
      redirect_to @report_template, alert: t("reporting.report_templates.errors.cannot_publish")
    end

    def archive
      authorize @report_template
      @report_template.do_archive!
      redirect_to @report_template, notice: t("reporting.report_templates.archived")
    rescue AASM::InvalidTransition => e
      Rails.logger.warn "Report template archive failed for template #{@report_template.id}: #{e.message}"
      redirect_to @report_template, alert: t("reporting.report_templates.errors.cannot_archive")
    end

    private

    def set_report_template
      @report_template = Reporting::ReportTemplate.find(params[:id])
    end

    def report_template_params
      params.require(:reporting_report_template).permit(:name, :description)
    end
  end
end
