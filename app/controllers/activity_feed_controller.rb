class ActivityFeedController < ApplicationController
  DORMITORY_RECORD_TYPES = %w[
    Dormitory::Resident
    Dormitory::Accommodation
    Dormitory::Room
    Dormitory::Building
    Dormitory::CommandantBuilding
  ].freeze

  def index
    authorize :activity_feed
    events = OutboxEvent.order(created_at: :desc).includes(:actor, :record)

    reporting_admin = current_user.has_role?("reporting.admin")
    dormitory_admin = current_user.has_role?("dormitory.admin")

    if reporting_admin && !dormitory_admin
      events = events.where.not(record_type: DORMITORY_RECORD_TYPES)
    elsif dormitory_admin && !reporting_admin
      events = events.where(record_type: DORMITORY_RECORD_TYPES)
    end

    @pagy, @events = pagy(:offset, events)
  end
end
