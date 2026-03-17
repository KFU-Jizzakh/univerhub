module Dormitory
  class BuildingsController < ApplicationController
    before_action :set_building, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize Dormitory::Building
      @pagy, @buildings = pagy(:offset, policy_scope(Dormitory::Building))

      building_ids = @buildings.map(&:id)
      room_stats = Dormitory::Room.kept
        .where(building_id: building_ids)
        .group(:building_id)
        .select("building_id, COUNT(*) AS rooms_count, SUM(capacity) AS total_cap, SUM(current_occupancy) AS total_occ")
        .index_by(&:building_id)

      @building_stats = @buildings.index_by(&:id).transform_values do |building|
        s = room_stats[building.id]
        cap = s&.total_cap.to_i
        occ = s&.total_occ.to_i
        rate = cap.positive? ? (occ.to_f / cap * 100).round(1) : 0
        { rooms_count: s&.rooms_count.to_i, occupancy_rate: rate }
      end
    end

    def show
      authorize @building
      @pagy, @building_rooms = pagy(:offset, @building.rooms.kept.ordered)
      @audit_events = OutboxEvent.where(record: @building).order(:created_at).includes(:actor)
    end

    def new
      @building = Dormitory::Building.new
      authorize @building
    end

    def create
      @building = Dormitory::Building.new(building_params)
      authorize @building

      @building.do_create!
      redirect_to @building, notice: t("dormitory.buildings.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @building
    end

    def update
      authorize @building
      @building.do_update!(building_params)
      redirect_to @building, notice: t("dormitory.buildings.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @building

      @building.do_discard!
      redirect_to dormitory_buildings_path, notice: t("dormitory.buildings.destroyed")
    end

    private

    def set_building
      @building = Dormitory::Building.with_discarded.find(params[:id])
    end

    def building_params
      params.require(:dormitory_building).permit(:name, :address, :floors_count, :description)
    end
  end
end
