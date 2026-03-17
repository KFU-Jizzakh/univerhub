module Reporting
  class ReportItemsController < ApplicationController
    before_action :set_report
    before_action :set_report_item

    def edit
      authorize @report, :update_items?
    end

    def edit_grade
      authorize @report, :grade?
    end

    def update
      authorize @report, :update_items?

      if @report_item.do_update_content!(report_item_params.to_h.symbolize_keys)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @report, notice: t("reporting.report_items.updated") }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def grade
      authorize @report, :grade?

      if @report_item.do_grade!(grade_params.to_h.symbolize_keys)
        respond_to do |format|
          format.turbo_stream { render :update }
          format.html { redirect_to @report, notice: t("reporting.report_items.graded") }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_report
      @report = Reporting::Report.find(params[:report_id])
    end

    def set_report_item
      @report_item = @report.report_items.find(params[:id])
    end

    def report_item_params
      params.require(:reporting_report_item).permit(:content, attachments: [])
    end

    def grade_params
      params.require(:reporting_report_item).permit(:grade, :grade_comment)
    end
  end
end
