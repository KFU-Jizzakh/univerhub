require "test_helper"

module Dormitory
  class AccommodationPolicyTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      @dormitory_admin = users(:dormitory_admin_user)
      @commandant = users(:dormitory_commandant_user)
      @plain_user = users(:reporter_user)
      @resident = dormitory_residents(:resident_one_not_settled)
      @room = dormitory_rooms(:room_101)
      @building = dormitory_buildings(:building_one)
    end

    def build_accommodation(room: @room, resident: @resident)
      Accommodation.new(room: room, resident: resident)
    end

    # --- new? ---

    test "admin can access new" do
      assert AccommodationPolicy.new(@admin, Accommodation).new?
    end

    test "dormitory admin can access new" do
      assert AccommodationPolicy.new(@dormitory_admin, Accommodation).new?
    end

    test "commandant can access new" do
      assert AccommodationPolicy.new(@commandant, Accommodation).new?
    end

    test "plain user cannot access new" do
      assert_not AccommodationPolicy.new(@plain_user, Accommodation).new?
    end

    # --- create? ---

    test "admin can create" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).create?
    end

    test "dormitory admin can create" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@dormitory_admin, acc).create?
    end

    test "commandant can create when room in assigned building" do
      acc = build_accommodation(room: @room)
      assert AccommodationPolicy.new(@commandant, acc).create?
    end

    test "commandant cannot create when room not in assigned building" do
      other_building = dormitory_buildings(:building_two)
      other_room = dormitory_rooms(:room_101_building_two)

      commandant_with_other = users(:dormitory_commandant_user)
      Dormitory::CommandantBuilding.active.where(user: commandant_with_other).destroy_all
      Dormitory::CommandantBuilding.create!(user: commandant_with_other, building: other_building)

      acc = build_accommodation(room: @room)
      assert_not AccommodationPolicy.new(commandant_with_other, acc).create?
    end

    test "commandant cannot create when room_id is blank" do
      acc = Dormitory::Accommodation.new(room_id: nil, resident: @resident)
      assert_not AccommodationPolicy.new(@commandant, acc).create?
    end

    test "plain user cannot create" do
      acc = build_accommodation
      assert_not AccommodationPolicy.new(@plain_user, acc).create?
    end

    # --- force? ---

    test "admin can force settle" do
      assert AccommodationPolicy.new(@admin, Accommodation).force?
    end

    test "dormitory admin can force settle" do
      assert AccommodationPolicy.new(@dormitory_admin, Accommodation).force?
    end

    test "commandant cannot force settle" do
      assert_not AccommodationPolicy.new(@commandant, Accommodation).force?
    end

    test "plain user cannot force settle" do
      assert_not AccommodationPolicy.new(@plain_user, Accommodation).force?
    end

    # --- index? ---

    test "admin can access index" do
      assert AccommodationPolicy.new(@admin, Accommodation).index?
    end

    test "dormitory admin can access index" do
      assert AccommodationPolicy.new(@dormitory_admin, Accommodation).index?
    end

    test "commandant can access index" do
      assert AccommodationPolicy.new(@commandant, Accommodation).index?
    end

    test "plain user cannot access index" do
      assert_not AccommodationPolicy.new(@plain_user, Accommodation).index?
    end

    # --- show? ---

    test "admin can view accommodation" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).show?
    end

    test "dormitory admin can view accommodation" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@dormitory_admin, acc).show?
    end

    test "commandant can view accommodation in assigned building" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@commandant, acc).show?
    end

    test "commandant cannot view accommodation in other building" do
      commandant_with_one = users(:dormitory_commandant_user)
      Dormitory::CommandantBuilding.active.where(user: commandant_with_one).destroy_all
      Dormitory::CommandantBuilding.create!(user: commandant_with_one, building: @building)

      other_room = dormitory_rooms(:room_101_building_two)
      acc = build_accommodation(room: other_room)
      assert_not AccommodationPolicy.new(commandant_with_one, acc).show?
    end

    test "plain user cannot view accommodation" do
      acc = build_accommodation
      assert_not AccommodationPolicy.new(@plain_user, acc).show?
    end

    # --- edit? / update? ---

    test "admin can edit accommodation" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).edit?
      assert AccommodationPolicy.new(@admin, acc).update?
    end

    test "dormitory admin can edit accommodation" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@dormitory_admin, acc).edit?
    end

    test "commandant can edit accommodation in assigned building" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@commandant, acc).edit?
    end

    test "commandant cannot edit accommodation in other building" do
      commandant_with_one = users(:dormitory_commandant_user)
      Dormitory::CommandantBuilding.active.where(user: commandant_with_one).destroy_all
      Dormitory::CommandantBuilding.create!(user: commandant_with_one, building: @building)

      other_room = dormitory_rooms(:room_101_building_two)
      acc = build_accommodation(room: other_room)
      assert_not AccommodationPolicy.new(commandant_with_one, acc).edit?
    end

    test "plain user cannot edit accommodation" do
      acc = build_accommodation
      assert_not AccommodationPolicy.new(@plain_user, acc).edit?
    end

    # --- new_transfer? / transfer? ---

    test "admin can new_transfer" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).new_transfer?
    end

    test "admin can transfer" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).transfer?
    end

    test "dormitory admin can new_transfer" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@dormitory_admin, acc).new_transfer?
    end

    test "commandant can new_transfer in assigned building" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@commandant, acc).new_transfer?
    end

    test "commandant cannot new_transfer in other building" do
      commandant_with_one = users(:dormitory_commandant_user)
      Dormitory::CommandantBuilding.active.where(user: commandant_with_one).destroy_all
      Dormitory::CommandantBuilding.create!(user: commandant_with_one, building: @building)

      other_room = dormitory_rooms(:room_101_building_two)
      acc = build_accommodation(room: other_room)
      assert_not AccommodationPolicy.new(commandant_with_one, acc).new_transfer?
    end

    test "plain user cannot new_transfer" do
      acc = build_accommodation
      assert_not AccommodationPolicy.new(@plain_user, acc).new_transfer?
    end

    # --- new_eviction? / evict? ---

    test "admin can new_eviction" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).new_eviction?
    end

    test "admin can evict" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@admin, acc).evict?
    end

    test "dormitory admin can new_eviction" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@dormitory_admin, acc).new_eviction?
    end

    test "commandant can new_eviction in assigned building" do
      acc = build_accommodation
      assert AccommodationPolicy.new(@commandant, acc).new_eviction?
    end

    test "commandant cannot new_eviction in other building" do
      commandant_with_one = users(:dormitory_commandant_user)
      Dormitory::CommandantBuilding.active.where(user: commandant_with_one).destroy_all
      Dormitory::CommandantBuilding.create!(user: commandant_with_one, building: @building)

      other_room = dormitory_rooms(:room_101_building_two)
      acc = build_accommodation(room: other_room)
      assert_not AccommodationPolicy.new(commandant_with_one, acc).new_eviction?
    end

    test "plain user cannot new_eviction" do
      acc = build_accommodation
      assert_not AccommodationPolicy.new(@plain_user, acc).new_eviction?
    end

    # --- policy_scope ---

    test "admin scope includes all accommodations" do
      scope = AccommodationPolicy::Scope.new(@admin, Accommodation.all).resolve
      assert_equal Accommodation.kept.count, scope.count
    end

    test "commandant scope only includes accommodations in assigned buildings" do
      scope = AccommodationPolicy::Scope.new(@commandant, Accommodation.all).resolve
      assert scope.all? { |acc| acc.room.building_id.in?(@commandant.assigned_building_ids) }
    end

    test "plain user scope returns none" do
      scope = AccommodationPolicy::Scope.new(@plain_user, Accommodation.all).resolve
      assert_empty scope
    end
  end
end
