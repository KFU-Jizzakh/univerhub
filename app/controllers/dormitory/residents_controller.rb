module Dormitory
  class ResidentsController < ApplicationController
    before_action :set_resident, only: [ :show, :edit, :update, :destroy ]
    def index
      authorize Dormitory::Resident
      @residents = policy_scope(Dormitory::Resident).includes(:current_room)
      @residents = @residents.where(status: params[:status]) if params[:status].present?
      @residents = @residents.where(gender: params[:gender]) if params[:gender].present?
      @residents = @residents.search_by_name(params[:query]) if params[:query].present?

      respond_to do |format|
        format.html { @pagy, @residents = pagy(:offset, @residents) }
        format.json do
          if params[:building_id].present?
            building = Dormitory::Building.find(params[:building_id])
            authorize building, :show?
            @residents = @residents
              .where(status: [ :settled, :temporarily_absent ])
              .where(dormitory_rooms: { building_id: building.id })
          end
          render json: @residents.map { |r|
            { id: r.id, full_name: r.full_name, room_number: r.current_room&.number, status: r.status }
          }
        end
      end
    end

    def show
      authorize @resident
      @accommodations = @resident.accommodations.kept.ordered.includes(:room, :receipts)
      @audit_events = OutboxEvent.where(record: @resident).order(:created_at).includes(:actor)
      @acc_events_by = OutboxEvent.where(record: @accommodations).includes(:actor)
        .group_by { |e| [ e.record_id, e.action ] }
    end

    def new
      @resident = Dormitory::Resident.new
      authorize @resident
    end

    def create
      @resident = Dormitory::Resident.new(resident_params)
      authorize @resident
      @resident.do_create!
      redirect_to @resident, notice: t("dormitory.residents.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @resident
    end

    def update
      authorize @resident
      @resident.do_update!(resident_params)
      redirect_to @resident, notice: t("dormitory.residents.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @resident
      @resident.do_discard!
      redirect_to dormitory_residents_path, notice: t("dormitory.residents.destroyed")
    rescue ActiveRecord::RecordInvalid
      redirect_to @resident, alert: @resident.errors.full_messages.join(", ")
    end

    def check_ticket
      authorize Dormitory::Resident
      number = params[:number].to_s.strip
      resident = policy_scope(Dormitory::Resident).find_by(student_ticket_number: number)
      if resident
        render json: { found: true, id: resident.id, full_name: resident.full_name }
      else
        render json: { found: false }
      end
    end

    private

    def set_resident
      @resident = Dormitory::Resident.with_discarded.find(params[:id])
    end

    def resident_params
      params.require(:dormitory_resident).permit(
        :last_name, :first_name, :middle_name,
        :gender, :date_of_birth,
        :phone, :email,
        :student_ticket_number,
        :photo
      )
    end
  end
end
