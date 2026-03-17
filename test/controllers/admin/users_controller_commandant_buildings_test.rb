require "test_helper"

class Admin::UsersController::CommandantBuildingsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dorm_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @building_one = dormitory_buildings(:building_one)
    @building_two = dormitory_buildings(:building_two)
  end

  test "dormitory.admin creates commandant with buildings" do
    sign_in_as(@dorm_admin)

    assert_difference "User.count" => 1, "Dormitory::CommandantBuilding.active.count" => 2 do
      post admin_users_path, params: {
        user: {
          email_address: "new_commandant@test.local",
          password: "password",
          password_confirmation: "password",
          role_ids: [ roles(:dormitory_commandant).id.to_s ],
          building_ids: [ @building_one.id.to_s, @building_two.id.to_s ]
        }
      }
    end

    new_user = User.find_by(email_address: "new_commandant@test.local")
    assert_redirected_to admin_user_path(new_user)
    assert_equal [ @building_one.id, @building_two.id ].sort, new_user.assigned_building_ids.sort
  end

  test "admin creates commandant with buildings" do
    sign_in_as(@admin)

    assert_difference "User.count" => 1, "Dormitory::CommandantBuilding.active.count" => 1 do
      post admin_users_path, params: {
        user: {
          email_address: "admin_commandant@test.local",
          password: "password",
          password_confirmation: "password",
          role_ids: [ roles(:dormitory_commandant).id.to_s ],
          building_ids: [ @building_one.id.to_s ]
        }
      }
    end

    new_user = User.find_by(email_address: "admin_commandant@test.local")
    assert_redirected_to admin_user_path(new_user)
    assert_equal [ @building_one.id ], new_user.assigned_building_ids
  end

  test "creates user without buildings when no commandant role" do
    sign_in_as(@admin)

    assert_no_difference "Dormitory::CommandantBuilding.count" do
      post admin_users_path, params: {
        user: {
          email_address: "no_buildings@test.local",
          password: "password",
          password_confirmation: "password",
          role_ids: [ roles(:admin).id.to_s ],
          building_ids: [ @building_one.id.to_s ]
        }
      }
    end
  end

  test "reassigns buildings on update" do
    sign_in_as(@dorm_admin)

    assert_equal [ @building_one.id, @building_two.id ].sort, @commandant.assigned_building_ids.sort

    patch admin_user_path(@commandant), params: {
      user: {
        email_address: @commandant.email_address,
        role_ids: [ roles(:dormitory_commandant).id.to_s ],
        building_ids: [ @building_two.id.to_s ]
      }
    }

    assert_redirected_to admin_user_path(@commandant)
    assert_equal [ @building_two.id ], @commandant.reload.assigned_building_ids

    deactivated = Dormitory::CommandantBuilding.deactivated.where(user: @commandant, building: @building_one)
    assert_equal 1, deactivated.count
  end

  test "removes all buildings on update" do
    sign_in_as(@dorm_admin)

    patch admin_user_path(@commandant), params: {
      user: {
        email_address: @commandant.email_address,
        role_ids: [ roles(:dormitory_commandant).id.to_s ],
        building_ids: []
      }
    }

    assert_redirected_to admin_user_path(@commandant)
    assert_equal [], @commandant.reload.assigned_building_ids

    assert_equal 2, @commandant.commandant_buildings.deactivated.count
  end

  test "shows assigned buildings on show page" do
    sign_in_as(@dorm_admin)
    get admin_user_path(@commandant)

    assert_response :success
    assert_select ".info-label", text: "Корпуса"
    assert_select ".status-badge", text: dormitory_buildings(:building_one).name
    assert_select ".status-badge", text: dormitory_buildings(:building_two).name
  end

  test "shows buildings fieldset on new form for dormitory.admin" do
    sign_in_as(@dorm_admin)
    get new_admin_user_path

    assert_response :success
    assert_select "legend", text: "Корпуса"
  end

  test "shows buildings fieldset on edit form with checked buildings" do
    sign_in_as(@dorm_admin)
    get edit_admin_user_path(@commandant)

    assert_response :success
    assert_select "legend", text: "Корпуса"
  end

  test "does not show buildings for reporting.admin" do
    sign_in_as(users(:reporting_admin_user))
    get new_admin_user_path

    assert_response :success
    assert_select "legend", text: "Корпуса", count: 0
  end

  test "create commandant creates OutboxEvents for buildings" do
    sign_in_as(@admin)

    assert_difference "OutboxEvent.count", 1 do
      post admin_users_path, params: {
        user: {
          email_address: "cb_commandant@test.local",
          password: "password",
          password_confirmation: "password",
          role_ids: [ roles(:dormitory_commandant).id.to_s ],
          building_ids: [ @building_one.id.to_s ]
        }
      }
    end

    new_user = User.find_by(email_address: "cb_commandant@test.local")
    cb = new_user.commandant_buildings.active.find_by(building: @building_one)
    event = OutboxEvent.where(record: cb, action: "dormitory.commandant_building.created").last
    assert_not_nil event
  end

  test "reassigns buildings creates OutboxEvents for deactivation and creation" do
    sign_in_as(@dorm_admin)

    new_building = Dormitory::Building.create!(name: "Корпус В", address: "ул. В, 3", floors_count: 2)
    old_count = OutboxEvent.count

    patch admin_user_path(@commandant), params: {
      user: {
        email_address: @commandant.email_address,
        role_ids: [ roles(:dormitory_commandant).id.to_s ],
        building_ids: [ @building_two.id.to_s, new_building.id.to_s ]
      }
    }

    assert_redirected_to admin_user_path(@commandant)

    new_events = OutboxEvent.where("id > ?", old_count)
    actions = new_events.pluck(:action)
    assert_includes actions, "dormitory.commandant_building.deactivated"
    assert_includes actions, "dormitory.commandant_building.created"
  end
end
