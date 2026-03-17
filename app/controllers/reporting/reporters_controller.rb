module Reporting
  class ReportersController < ApplicationController
    def index
      authorize [ :reporting, :reporter ]
      @reporters = User.with_role("reporting.reporter").includes(:profile).order(:email_address)
    end

    def show
      authorize [ :reporting, :reporter ]
      @reporter = User.find(params[:id])

      unless @reporter.has_role?("reporting.reporter")
        redirect_to reporting_reporters_path, alert: t("reporting.reporters.not_a_reporter")
        return
      end

      @reports = policy_scope(Reporting::Report).where(reporter: @reporter).order(created_at: :desc)
    end
  end
end
