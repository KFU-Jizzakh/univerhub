module Dormitory
  class RoomsController < ApplicationController
    before_action :set_room, only: [ :show, :edit, :update, :destroy ]
    before_action :set_buildings, only: [ :index, :new, :create, :edit, :update ]

    def index
      authorize Dormitory::Room
      @rooms = policy_scope(Dormitory::Room)
      @rooms = @rooms.where(building_id: params[:building_id]) if params[:building_id].present?
      @pagy, @rooms = pagy(:offset, @rooms)
    end

    def show
      authorize @room
      @active_accommodations = @room.accommodations.where(status: :active).includes(:resident)
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

      render json: rooms.ordered.map { |r|
        { id: r.id, number: r.number, floor: r.floor, capacity: r.capacity,
          current_occupancy: r.current_occupancy, available_slots: r.available_slots,
          gender_restriction: r.gender_restriction, status: r.status }
      }
    end

    private

    def set_room
      @room = Dormitory::Room.with_discarded.find(params[:id])
    end

    def set_buildings
      @buildings = policy_scope(Dormitory::Building)
    end

    def room_params
      params.require(:dormitory_room).permit(:number, :building_id, :floor, :capacity, :gender_restriction)
    end
  end
end
