module Reporting
  class ReportCommentsController < ApplicationController
    before_action :set_report
    before_action :authorize_comment_access, only: [ :create, :destroy ]

    def create
      @comment = @report.comments.build(comment_params)
      @comment.user = Current.user

      @comment.do_create!
      redirect_to @report, notice: t("reporting.comments.created")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to @report, alert: e.record.errors.full_messages.join(", ")
    end

    def destroy
      @comment = @report.comments.find(params[:id])
      authorize @comment
      @comment.do_destroy!
      redirect_to @report, notice: t("reporting.comments.destroyed")
    rescue ActiveRecord::RecordNotDestroyed => e
      redirect_to @report, alert: e.record.errors.full_messages.join(", ")
    end

    private

    def set_report
      @report = Reporting::Report.find(params[:report_id])
    end

    def authorize_comment_access
      authorize @report, :access_comments?
    end

    def comment_params
      params.require(:reporting_report_comment).permit(:body)
    end
  end
end
