module Dormitory
  class AccommodationsController < ApplicationController
    before_action :set_accommodation, only: [ :show, :edit, :update, :new_transfer, :transfer, :new_eviction, :evict ]
    before_action :set_resident, only: [ :new, :create ]
    before_action :set_buildings, only: [ :new, :create ]

    def index
      authorize Dormitory::Accommodation
      @buildings = policy_scope(Dormitory::Building)
      @academic_years = Dormitory::AcademicYear.kept.order(:start_date)
      @accommodations = policy_scope(Dormitory::Accommodation).ordered.includes(:resident, :receipts, room: :building)
      @accommodations = @accommodations.where(dormitory_rooms: { building_id: params[:building_id] }) if params[:building_id].present?
      @accommodations = @accommodations.where(academic_year_id: params[:academic_year_id]) if params[:academic_year_id].present?
      @accommodations = @accommodations.where(status: params[:status]) if params[:status].present?
      @pagy, @accommodations = pagy(:offset, @accommodations)
    end

    def show
      authorize @accommodation
      @audit_events = OutboxEvent.where(record: @accommodation).order(:created_at).includes(:actor)
    end

    def new
      authorize Dormitory::Accommodation
      @accommodation = Dormitory::Accommodation.new(resident: @resident, start_date: Date.current)
    end

    def create
      @accommodation = Dormitory::Accommodation.new(accommodation_params)
      authorize @accommodation

      force = policy(@accommodation).force? && params[:force].present?
      @accommodation.do_settle!(force: force)

      redirect_to dormitory_resident_path(@resident), notice: t("dormitory.accommodations.settled", room_number: @accommodation.room.number)
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @accommodation
    end

    def update
      authorize @accommodation
      @accommodation.do_update!(accommodation_edit_params)
      redirect_to dormitory_accommodation_path(@accommodation), notice: t("dormitory.accommodations.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def new_transfer
      authorize @accommodation
      unless @accommodation.active?
        redirect_to dormitory_accommodation_path(@accommodation), alert: t("dormitory.accommodations.not_active")
        return
      end

      @resident = @accommodation.resident
      @buildings = buildings_for_select
      @new_accommodation = Dormitory::Accommodation.new(resident: @resident, start_date: Date.current)
    end

    def transfer
      authorize @accommodation
      @resident = @accommodation.resident
      @buildings = buildings_for_select
      @new_accommodation = Dormitory::Accommodation.new(
        transfer_params.except(:eviction_reason).merge(resident: @resident)
      )

      @accommodation.do_transfer!(@new_accommodation, eviction_reason: transfer_params[:eviction_reason])

      redirect_to dormitory_resident_path(@resident),
                  notice: t("dormitory.accommodations.transferred", room_number: @new_accommodation.room.number)
    rescue ActiveRecord::RecordInvalid
      render :new_transfer, status: :unprocessable_entity
    end

    def new_eviction
      authorize @accommodation
      unless @accommodation.active?
        redirect_to dormitory_accommodation_path(@accommodation), alert: t("dormitory.accommodations.not_active")
      end
    end

    def evict
      authorize @accommodation
      @accommodation.do_evict!(eviction_reason: eviction_params[:eviction_reason], comment: eviction_params[:comment])

      redirect_to dormitory_resident_path(@accommodation.resident),
                  notice: t("dormitory.accommodations.evicted", room_number: @accommodation.room.number)
    rescue ActiveRecord::RecordInvalid
      render :new_eviction, status: :unprocessable_entity
    end

    private

    def set_accommodation
      @accommodation = Dormitory::Accommodation.with_discarded.includes(:receipts).find(params[:id])
    end

    def set_resident
      resident_id = action_name == "new" ? params[:resident_id] : accommodation_params[:resident_id]
      @resident = Dormitory::Resident.kept.find(resident_id)
    end

    def set_buildings
      @buildings = policy_scope(Dormitory::Building)
    end

    def accommodation_params
      params.require(:dormitory_accommodation).permit(
        :resident_id, :room_id,
        :application_number, :contract_number,
        :start_date, :planned_end_date, :comment,
        :application_file, :contract_file, :payment_receipt,
        :required_amount,
        receipts_attributes: [ :id, :amount, :paid_at, :comment, :attachment, :_destroy ]
      )
    end

    def accommodation_edit_params
      params.require(:dormitory_accommodation).permit(
        :application_number, :contract_number,
        :start_date, :planned_end_date, :comment,
        :application_file, :contract_file, :payment_receipt,
        :required_amount
      )
    end

    def transfer_params
      params.require(:dormitory_accommodation).permit(
        :room_id,
        :application_number, :contract_number,
        :start_date, :planned_end_date, :comment,
        :application_file, :contract_file, :payment_receipt,
        :eviction_reason,
        :required_amount,
        receipts_attributes: [ :id, :amount, :paid_at, :comment, :attachment, :_destroy ]
      )
    end

    def buildings_for_select
      policy_scope(Dormitory::Building)
    end

    def eviction_params
      params.require(:dormitory_accommodation).permit(:eviction_reason, :comment)
    end
  end
end
