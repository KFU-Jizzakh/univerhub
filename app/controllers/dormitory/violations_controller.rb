module Dormitory
  class ViolationsController < ApplicationController
    before_action :set_violation, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize Dormitory::Violation
      @violations = policy_scope(Dormitory::Violation).includes(:resident)
      @violations = @violations.where(violation_type: params[:violation_type]) if params[:violation_type].present?
      @violations = @violations.where(status: params[:status]) if params[:status].present?
      @pagy, @violations = pagy(:offset, @violations)
    end

    def show
      authorize @violation
      @audit_events = OutboxEvent.where(record: @violation).order(:created_at).includes(:actor)
    end

    def new
      @violation = Dormitory::Violation.new(resident_id: params[:resident_id])
      authorize @violation
    end

    def create
      @violation = Dormitory::Violation.new(violation_params)
      authorize @violation
      @violation.do_create!
      redirect_to @violation, notice: t("dormitory.violations.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @violation
    end

    def update
      authorize @violation
      @violation.do_update!(violation_params)
      redirect_to @violation, notice: t("dormitory.violations.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @violation
      @violation.do_discard!
      redirect_to dormitory_violations_path, notice: t("dormitory.violations.destroyed")
    end

    private

    def set_violation
      @violation = Dormitory::Violation.with_discarded.find(params[:id])
    end

    def violation_params
      params.require(:dormitory_violation).permit(
        :resident_id,
        :violation_type,
        :occurred_at,
        :place,
        :description,
        :status,
        :reviewed_at,
        :review_result,
        :commandant_comment,
        :protocol_file,
      )
    end
  end
end
