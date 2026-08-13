module Dormitory
  class RoomsController < ApplicationController
    before_action :set_room, only: [ :show, :edit, :update, :destroy ]
    before_action :set_buildings, only: [ :index, :new, :create, :edit, :update ]

    def index
      # PURPOSE: List rooms with aggregated bed statistics and building filter
      # SPECIFICATION: SPEC-DORM-02, SPEC-DORM-11
      authorize Dormitory::Room
      @rooms = policy_scope(Dormitory::Room)
      @rooms = @rooms.where(building_id: params[:building_id]) if params[:building_id].present?

      @total_beds = @rooms.sum(:capacity)
      @occupied_beds = @rooms.sum(:current_occupancy)
      @free_beds = [ @total_beds - @occupied_beds, 0 ].max
      @occupancy_rate = @total_beds.positive? ? (@occupied_beds.to_f / @total_beds * 100).round(1) : 0

      @pagy, @rooms = pagy(:offset, @rooms)
    end

    def show
      authorize @room
      @active_accommodations = @room.accommodations.where(status: %w[active pending]).includes(:resident)
      @audit_events = OutboxEvent.where(record: @room).order(:created_at).includes(:actor)
      @acc_events_by = OutboxEvent.where(record: @active_accommodations).includes(:actor)
        .group_by { |e| [ e.record_id, e.action ] }
    end

    def new
      @room = Dormitory::Room.new
      authorize @room
    end

    def create
      @room = Dormitory::Room.new(room_params)
      authorize @room
      @room.do_create!
      redirect_to @room, notice: t("dormitory.rooms.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @room
    end

    def update
      authorize @room
      @room.do_update!(room_params)
      redirect_to @room, notice: t("dormitory.rooms.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @room
      @room.do_discard!
      redirect_to dormitory_rooms_path, notice: t("dormitory.rooms.destroyed")
    rescue ActiveRecord::RecordInvalid
      redirect_to @room, alert: @room.errors.full_messages.join(", ")
    end

    def suggest_number
      authorize Dormitory::Room, :suggest_number?
      room = Dormitory::Room.new(building_id: params[:building_id], floor: params[:floor])
      render json: { number: room.suggested_number }
    end

    def available
      authorize Dormitory::Room, :index?

      rooms = policy_scope(Dormitory::Room)
        .where(status: [ :free, :partially_occupied ])

      rooms = rooms.where(building_id: params[:building_id]) if params[:building_id].present?

      if params[:gender].present?
        rooms = rooms.where("gender_restriction IS NULL OR gender_restriction = ?", Dormitory::Room.gender_restrictions[params[:gender]])
      end

      if params[:course].present? && params[:course].to_i.in?(Dormitory::Room::COURSE_RANGE)
        rooms = rooms.where("allowed_courses IS NULL OR ? = ANY(allowed_courses)", params[:course].to_i)
      end

      occupied_by_room = Dormitory::Room.occupied_bed_labels_by_room(rooms)

      render json: rooms.ordered.map { |r|
        { id: r.id, number: r.number, floor: r.floor, capacity: r.capacity,
          current_occupancy: r.current_occupancy, available_slots: r.available_slots,
          free_bed_labels: r.free_bed_labels(occupied_by_room[r.id] || []),
          gender_restriction: r.gender_restriction, status: r.status }
      }
    end

    # PURPOSE: Returns the free bed labels of a room as JSON for the bed select
    # SPECIFICATION: SPEC-DORM-12
    def beds
      authorize Dormitory::Room, :index?
      room = policy_scope(Dormitory::Room).find(params[:id])
      render json: room.free_bed_labels
    end

    private

    def set_room
      @room = Dormitory::Room.with_discarded.find(params[:id])
    end

    def set_buildings
      @buildings = policy_scope(Dormitory::Building)
    end

    def room_params
      permitted = params.require(:dormitory_room).permit(:number, :building_id, :floor, :capacity, :gender_restriction,
                                                         allowed_courses: [])
      permitted[:allowed_courses] = permitted[:allowed_courses]&.reject(&:blank?)
      permitted
    end
  end
end
