module Dormitory
  module Exports
    class FreeSlotsController < ApplicationController
      def index
        authorize :dormitory_export, policy_class: Dormitory::ExportPolicy

        @buildings = policy_scope(Dormitory::Building)
        @academic_years = policy_scope(Dormitory::AcademicYear).ordered

        @preview = policy_scope(Dormitory::Room)
          .kept
          .includes(:building)
          .order("dormitory_buildings.name", :floor, :number)
          .limit(50)

        @preview = @preview.where(building_id: params[:building_id]) if params[:building_id].present?

        respond_to do |format|
          format.html
          format.csv do
            csv = Dormitory::ExportService.free_slots_csv(policy_scope(Dormitory::Room), export_filters)
            send_data csv, filename: "free_slots_#{Date.current}.csv", type: "text/csv"
          end
        end
      end

      private

      def export_filters
        params.permit(:building_id).to_h.symbolize_keys
      end
    end
  end
end
