ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    set_fixture_class(
      reporting_reports: Reporting::Report,
      reporting_report_items: Reporting::ReportItem,
      reporting_report_templates: Reporting::ReportTemplate,
      reporting_report_template_items: Reporting::ReportTemplateItem,
      reporting_report_comments: Reporting::ReportComment,
      dormitory_buildings: Dormitory::Building,
      dormitory_rooms: Dormitory::Room,
      dormitory_commandant_buildings: Dormitory::CommandantBuilding,
      dormitory_accommodations: Dormitory::Accommodation,
      dormitory_academic_years: Dormitory::AcademicYear
    )
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
