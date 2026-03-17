module Dormitory
  module Exports
    class AccommodationHistoriesController < ApplicationController
      def index
        authorize :dormitory_export, policy_class: Dormitory::ExportPolicy

        @buildings = policy_scope(Dormitory::Building)
        @academic_years = policy_scope(Dormitory::AcademicYear).ordered

        @preview = policy_scope(Dormitory::Accommodation).kept
          .includes(:resident, room: :building)
          .order("dormitory_buildings.name", "dormitory_rooms.floor", "dormitory_rooms.number", "dormitory_accommodations.start_date")
          .limit(50)

        @preview = @preview.joins(:room).where(dormitory_rooms: { building_id: params[:building_id] }) if params[:building_id].present?
        @preview = @preview.where(status: params[:status]) if params[:status].present?
        @preview = @preview.where("start_date >= ?", params[:date_from]) if params[:date_from].present?
        @preview = @preview.where("start_date <= ?", params[:date_to]) if params[:date_to].present?
        @preview = @preview.where(academic_year_id: params[:academic_year_id]) if params[:academic_year_id].present?

        respond_to do |format|
          format.html
          format.csv do
            csv = Dormitory::ExportService.history_csv(
              policy_scope(Dormitory::Accommodation), export_filters
            )
            send_data csv, filename: "accommodation_history_#{Date.current}.csv", type: "text/csv"
          end
        end
      end

      private

      def export_filters
        params.permit(:building_id, :academic_year_id, :date_from, :date_to, :status)
              .to_h.symbolize_keys
      end
    end
  end
end
