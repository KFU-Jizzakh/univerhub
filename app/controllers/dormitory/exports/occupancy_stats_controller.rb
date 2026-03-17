module Dormitory
  module Exports
    class OccupancyStatsController < ApplicationController
      def index
        authorize :dormitory_export, policy_class: Dormitory::ExportPolicy

        @buildings = policy_scope(Dormitory::Building)
        @academic_years = policy_scope(Dormitory::AcademicYear).ordered

        respond_to do |format|
          format.html
          format.csv do
            csv = Dormitory::ExportService.occupancy_stats_csv(policy_scope(Dormitory::Building))
            send_data csv, filename: "occupancy_stats_#{Date.current}.csv", type: "text/csv"
          end
        end
      end
    end
  end
end
