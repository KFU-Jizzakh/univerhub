module Dormitory
  class BatchRoomsController < ApplicationController
    # PURPOSE: Mass creation of dormitory rooms from a number range with editable preview table
    # SPECIFICATION: SPEC-DORM-02

    def new
      authorize Dormitory::Room, :create?
      @buildings = policy_scope(Dormitory::Building)
      @building_id = params[:building_id] if params[:building_id].present?
    end

    def create
      authorize Dormitory::Room, :create?
      @buildings = policy_scope(Dormitory::Building)

      raw_rooms = params[:rooms]
      rooms_data = raw_rooms.is_a?(Array) ? raw_rooms.reject { |r| r.blank? } : []

      if rooms_data.empty?
        flash.now[:alert] = t("views.dormitory.batch_rooms.errors.no_rooms")
        render :new, status: :unprocessable_entity
        return
      end

      @building_id = rooms_data.first[:building_id]
      @floor = rooms_data.first[:floor]
      @rooms_data = rooms_data

      unless Dormitory::Building.where(id: @building_id).exists?
        flash.now[:alert] = t("views.dormitory.batch_rooms.errors.building_not_found")
        render :new, status: :unprocessable_entity
        return
      end

      allowed_genders = Dormitory::Room.gender_restrictions.keys

      ActiveRecord::Base.transaction do
        rooms_data.each do |room_data|
          gender = room_data[:gender_restriction].presence
          gender = nil unless gender.in?(allowed_genders)

          Dormitory::Room.new(
            building_id: room_data[:building_id],
            floor: room_data[:floor],
            number: room_data[:number],
            capacity: room_data[:capacity],
            gender_restriction: gender
          ).do_create!
        end
      end

      redirect_to dormitory_rooms_path(building_id: @building_id),
                  notice: t("views.dormitory.batch_rooms.created", count: rooms_data.size)
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.map { |m| "#{e.record.number}: #{m}" }.join("; ")
      render :new, status: :unprocessable_entity
    end
  end
end
