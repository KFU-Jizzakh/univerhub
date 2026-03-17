module Dormitory
  class DashboardController < ApplicationController
    def index
      authorize :dashboard, policy_class: Dormitory::DashboardPolicy

      @active_year = Dormitory::AcademicYear.active.first

      @buildings_scope = current_user.has_role?("dormitory.commandant") ?
                         current_user.assigned_buildings :
                         Dormitory::Building.kept

      @buildings_count = @buildings_scope.count
      @rooms = Dormitory::Room.kept.where(building: @buildings_scope)
      @rooms_count = @rooms.count
      @residents = Dormitory::Resident.kept.where(current_room: @rooms)
      @residents_count = @residents.count

      @total_capacity = @rooms.sum(:capacity)
      @current_occupancy = @rooms.sum(:current_occupancy)
      @occupancy_rate = @total_capacity.positive? ? (@current_occupancy.to_f / @total_capacity * 100).round(1) : 0

      building_aggregates = @rooms.group(:building_id)
                                  .select("building_id, SUM(capacity) AS total_capacity, SUM(current_occupancy) AS total_occupancy")
                                  .to_a
                                  .index_by(&:building_id)

      @building_stats = @buildings_scope.map do |building|
        agg = building_aggregates[building.id]
        cap = agg&.total_capacity.to_i
        occ = agg&.total_occupancy.to_i
        rate = cap.positive? ? (occ.to_f / cap * 100).round(1) : 0
        { building: building, occupancy_rate: rate, capacity: cap, occupancy: occ }
      end

      @room_status_counts = @rooms.group(:status).count

      @resident_gender_counts = @residents.group(:gender).count
      @resident_status_counts = @residents.group(:status).count

      @overcrowded_rooms = @rooms.where("current_occupancy > capacity").includes(:building)

      @overdue_accommodations = Dormitory::Accommodation.overdue
        .where(room: @rooms)
        .includes(:resident, room: :building)
        .order("dormitory_rooms.building_id, dormitory_rooms.number")

      dormitory_record_types = %w[
        Dormitory::Building
        Dormitory::Room
        Dormitory::Resident
        Dormitory::Accommodation
      ]

      recent = OutboxEvent.where(record_type: dormitory_record_types)
                          .order(created_at: :desc)
                          .includes(:actor)

      if current_user.has_role?("dormitory.commandant")
        building_ids = @buildings_scope.ids
        room_ids = @rooms.ids
        resident_ids = @residents.ids
        accommodation_ids = Dormitory::Accommodation.where(room_id: room_ids).ids

        recent = recent.where(
          "(record_type = ? AND record_id IN (?)) OR (record_type = ? AND record_id IN (?)) OR (record_type = ? AND record_id IN (?)) OR (record_type = ? AND record_id IN (?))",
          "Dormitory::Building", building_ids,
          "Dormitory::Room", room_ids,
          "Dormitory::Resident", resident_ids,
          "Dormitory::Accommodation", accommodation_ids
        )
      end

      @recent_events = recent.limit(10)
    end
  end
end
