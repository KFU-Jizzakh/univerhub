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
          render json: @residents.limit(50).map { |r|
            { id: r.id, full_name: r.full_name, room_number: r.current_room&.number, status: r.status }
          }
        end
      end
    end

    def show
      authorize @resident
      @accommodations = @resident.accommodations.kept.ordered.includes(:room, :receipts)
      @violations = @resident.violations.kept.ordered
      @audit_events = OutboxEvent.where(record: @resident).order(:created_at).includes(:actor)
      @acc_events_by = OutboxEvent.where(record: @accommodations).includes(:actor)
        .group_by { |e| [ e.record_id, e.action ] }
    end

    def new
      @resident = Dormitory::Resident.new
      authorize @resident
      @buildings = policy_scope(Dormitory::Building)
      set_placement_suggestion
    end

    def create
      @resident = Dormitory::Resident.new(resident_params)
      authorize @resident

      placement_params = params[:placement] || {}
      place = ActiveModel::Type::Boolean.new.cast(placement_params[:place])

      service = Dormitory::ResidentRegistrationService.new(room_scope: policy_scope(Dormitory::Room))
      result = service.call(
        resident_params: resident_params,
        place: place,
        manual_room_id: placement_params[:room_id],
        manual_bed_label: placement_params[:bed_label],
        start_date: placement_params[:start_date],
        planned_end_date: placement_params[:planned_end_date],
        required_amount: placement_params[:required_amount],
        receipt_params: params[:receipt] || {}
      )
      @resident = service.resident

      if result == :pending
        redirect_to @resident,
                    notice: t("dormitory.residents.registered_with_place",
                              room_number: service.accommodation.room.number,
                              bed_label: service.accommodation.bed_label)
      else
        redirect_to @resident, notice: t("dormitory.residents.created")
      end
    rescue ActiveRecord::RecordInvalid => e
      @resident = service.resident
      @resident.errors.merge!(e.record.errors) unless e.record == @resident
      @buildings = policy_scope(Dormitory::Building)
      set_placement_suggestion
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

    # PURPOSE: Server-side suggestion of the next free room and bed for a given gender and course, used to prefill the placement selects
    # SPECIFICATION: SPEC-DORM-12
    def preview_place
      authorize Dormitory::Resident, :create_with_placement?
      resident = Dormitory::Resident.new(gender: params[:gender], course: params[:course])
      room = Dormitory::Room.best_available_for(resident, scope: policy_scope(Dormitory::Room))

      if room
        render json: {
          room_id: room.id,
          building_id: room.building_id,
          building: room.building.name,
          room_number: room.number,
          bed_label: room.free_bed_labels.first
        }
      else
        render json: { room_id: nil }
      end
    end

    private

    # PURPOSE: Prefills the placement selects with the next free room and bed, or keeps the previously chosen values on form re-render
    # SPECIFICATION: SPEC-DORM-12
    def set_placement_suggestion
      @placement_start_date = params.dig(:placement, :start_date).presence || Date.current
      @placement_end_date = params.dig(:placement, :planned_end_date).presence || Date.current + 1.year
      @placement_required_amount = params.dig(:placement, :required_amount)
      @receipt_amount = params.dig(:receipt, :amount)
      @receipt_paid_at = params.dig(:receipt, :paid_at)
      requested_room = policy_scope(Dormitory::Room).find_by(id: params.dig(:placement, :room_id))
      requested_building = policy_scope(Dormitory::Building).find_by(id: params.dig(:placement, :building_id))
      @manual_building_selected = requested_building.present? && requested_room.blank?
      if requested_room
        @suggested_room = requested_room
        @suggested_building = requested_room.building
        @suggested_bed = params.dig(:placement, :bed_label)
      else
        candidate = Dormitory::Resident.new(gender: @resident.gender, course: @resident.course || 1)
        @suggested_room = Dormitory::Room.best_available_for(candidate, scope: policy_scope(Dormitory::Room),
                                                            building_id: requested_building&.id)
        @suggested_building = requested_building || @suggested_room&.building
        @suggested_bed = @suggested_room&.free_bed_labels&.first
      end

      @suggested_rooms = Dormitory::Room.available_for(@resident.gender, scope: policy_scope(Dormitory::Room),
                                                                          building_id: @suggested_room&.building_id,
                                                                          course: @resident.course || 1).to_a
      @suggested_rooms = [ @suggested_room ] + (@suggested_rooms - [ @suggested_room ]) if @suggested_room
      @occupied_labels = Dormitory::Room.occupied_bed_labels_by_room(@suggested_rooms)
      @suggested_beds = @suggested_room ? @suggested_room.free_bed_labels(@occupied_labels[@suggested_room.id] || []) : []
      @suggested_beds += [ @suggested_bed ] if @suggested_bed.present? && !@suggested_beds.include?(@suggested_bed)
    end

    def set_resident
      @resident = Dormitory::Resident.with_discarded.find(params[:id])
    end

    def resident_params
      params.require(:dormitory_resident).permit(
        :last_name, :first_name, :middle_name,
        :gender, :course, :date_of_birth,
        :phone, :email,
        :student_ticket_number,
        :photo,
        :application_number, :contract_number,
        :application_file, :contract_file
      )
    end
  end
end
