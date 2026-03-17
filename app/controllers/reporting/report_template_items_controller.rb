module Reporting
  class ReportTemplateItemsController < ApplicationController
    before_action :set_report_template
    before_action :set_item, only: [ :edit, :update, :destroy ]

    def new
      @item = @report_template.items.build
      authorize @report_template, :update?
    end

    def create
      @item = @report_template.items.build(item_params)
      authorize @report_template, :update?

      if @item.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @report_template, notice: t("reporting.report_template_items.created") }
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @report_template, :update?
    end

    def update
      authorize @report_template, :update?

      if @item.update(item_params)
        redirect_to @report_template, notice: t("reporting.report_template_items.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @report_template, :update?
      @item.destroy!

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @report_template, notice: t("reporting.report_template_items.destroyed") }
      end
    end

    private

    def set_report_template
      @report_template = Reporting::ReportTemplate.find(params[:report_template_id])
    end

    def set_item
      @item = @report_template.items.find(params[:id])
    end

    def item_params
      params.require(:reporting_report_template_item).permit(:name, :description, :position, :max_grade, :attachments_required)
    end
  end
end
