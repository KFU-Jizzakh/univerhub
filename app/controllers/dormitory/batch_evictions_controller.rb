module Dormitory
  class BatchEvictionsController < ApplicationController
    def index
      authorize Dormitory::BatchOperation
      @batch_operations = policy_scope(Dormitory::BatchOperation)
    end

    def new
      authorize Dormitory::BatchOperation
      @academic_year = Dormitory::AcademicYear.active.first
      if @academic_year.nil?
        redirect_to dormitory_dashboard_path, alert: t("dormitory.batch_operations.errors.no_active_year")
        return
      end
      @buildings = policy_scope(Dormitory::Building)
    end

    def create
      authorize Dormitory::BatchOperation

      @academic_year = Dormitory::AcademicYear.active.first
      if @academic_year.nil?
        redirect_to dormitory_dashboard_path, alert: t("dormitory.batch_operations.errors.no_active_year")
        return
      end

      building = Dormitory::Building.find(params[:building_id])
      authorize building, :show?

      service = Dormitory::BatchEvictionService.new(
        academic_year: @academic_year,
        building: building,
        resident_ids: Array(params[:resident_ids]).reject(&:blank?),
        eviction_reason: params[:eviction_reason],
        comment: params[:comment],
        performed_by: current_user
      )

      @batch_operation = service.call
      redirect_to dormitory_batch_eviction_path(@batch_operation)
    rescue ArgumentError => e
      set_form_state(building)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def show
      @batch_operation = policy_scope(Dormitory::BatchOperation).find(params[:id])
      authorize @batch_operation
    end

    private

    def set_form_state(building)
      @buildings = policy_scope(Dormitory::Building)
      @selected_building = building
    end
  end
end
