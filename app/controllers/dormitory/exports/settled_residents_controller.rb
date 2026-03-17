module Dormitory
  module Exports
    class SettledResidentsController < ApplicationController
      def index
        authorize :dormitory_export, policy_class: Dormitory::ExportPolicy

        @buildings = policy_scope(Dormitory::Building)
        @academic_years = policy_scope(Dormitory::AcademicYear).ordered

        @preview = policy_scope(Dormitory::Resident)
          .where(status: [ :settled, :temporarily_absent ])
          .includes(current_room: :building)
          .order("dormitory_buildings.name", "dormitory_rooms.floor", "dormitory_rooms.number")
          .limit(50)

        @preview = @preview.joins(:current_room).where(dormitory_rooms: { building_id: params[:building_id] }) if params[:building_id].present?

        respond_to do |format|
          format.html
          format.csv do
            csv = Dormitory::ExportService.settled_residents_csv(
              policy_scope(Dormitory::Resident), export_filters
            )
            send_data csv, filename: "settled_residents_#{Date.current}.csv", type: "text/csv"
          end
        end
      end

      private

      def export_filters
        params.permit(:building_id, :academic_year_id, :date_from, :date_to, :status, :floor, :room_id)
              .to_h.symbolize_keys
      end
    end
  end
end
