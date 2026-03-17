module Dormitory
  class AcademicYearsController < ApplicationController
    before_action :set_academic_year, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize Dormitory::AcademicYear
      @academic_years = policy_scope(Dormitory::AcademicYear).ordered
    end

    def show
      authorize @academic_year
      @audit_events = OutboxEvent.where(record: @academic_year).order(:created_at).includes(:actor)
    end

    def new
      authorize Dormitory::AcademicYear
      @academic_year = Dormitory::AcademicYear.new
    end

    def create
      @academic_year = Dormitory::AcademicYear.new(academic_year_params)
      authorize @academic_year
      @academic_year.do_create!
      redirect_to dormitory_academic_year_path(@academic_year), notice: t("dormitory.academic_years.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @academic_year
    end

    def update
      authorize @academic_year
      status_event = params.dig(:dormitory_academic_year, :status_event)
      case status_event
      when "activate"
        @academic_year.do_activate!
        redirect_to dormitory_academic_year_path(@academic_year), notice: t("dormitory.academic_years.activated")
      when "close"
        @academic_year.do_close!
        redirect_to dormitory_academic_year_path(@academic_year), notice: t("dormitory.academic_years.closed")
      else
        @academic_year.do_update!(academic_year_update_params)
        redirect_to dormitory_academic_year_path(@academic_year), notice: t("dormitory.academic_years.updated")
      end
    rescue ActiveRecord::RecordInvalid
      if status_event.present?
        redirect_to dormitory_academic_year_path(@academic_year),
                    alert: @academic_year.errors.full_messages.to_sentence
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @academic_year

      @academic_year.do_discard!
      redirect_to dormitory_academic_years_path, notice: t("dormitory.academic_years.destroyed")
    rescue ActiveRecord::RecordInvalid
      redirect_to dormitory_academic_years_path,
                  alert: @academic_year.errors.full_messages.to_sentence
    end

    private

    def set_academic_year
      @academic_year = Dormitory::AcademicYear.with_discarded.find(params[:id])
    end

    def academic_year_params
      params.require(:dormitory_academic_year).permit(:name, :start_date, :end_date, :status_event)
    end

    def academic_year_update_params
      params.require(:dormitory_academic_year).permit(:name, :start_date, :end_date)
    end
  end
end
