require "test_helper"

class Dormitory::ResidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @registrar = users(:dormitory_registrar_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
    @building_two = dormitory_buildings(:building_two)
    @resident = dormitory_residents(:resident_one_not_settled)
    @settled_resident = dormitory_residents(:resident_two_settled)

    @unassigned_building = Dormitory::Building.create!(
      name: "Неassignовый корпус", address: "ул. Новая, 9", floors_count: 2,
    )
    @room_unassigned = Dormitory::Room.create!(
      number: "999", building: @unassigned_building, floor: 1, capacity: 2,
    )
    @resident_unassigned = Dormitory::Resident.create!(
      last_name: "Чужой", first_name: "Человек", gender: :male, course: 1,
      date_of_birth: 20.years.ago, student_ticket_number: "UNASSIGNED2",
    )
    # Settle the unassigned resident so the commandant restriction applies via current_room
    acc = Dormitory::Accommodation.new(
      resident: @resident_unassigned,
      room: @room_unassigned,
      application_number: "APP-999",
      contract_number: "CNT-999",
      start_date: Date.current,
      planned_end_date: Date.current + 1.year,
    )
    acc.application_file.attach(
      io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf",
    )
    acc.contract_file.attach(
      io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf",
    )
    acc.receipts.build(
      amount: 10000, paid_at: Date.current,
      attachment: { io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf" }
    )
    acc.do_settle!
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires auth" do
    get dormitory_residents_path
    assert_redirected_to new_session_path
  end

  test "index denied for manager" do
    sign_in_as @manager
    get dormitory_residents_path
    assert_redirected_to root_path
  end

  test "index renders for admin" do
    sign_in_as @admin
    get dormitory_residents_path
    assert_response :success
  end

  test "index renders for dormitory.admin" do
    sign_in_as @dormitory_admin
    get dormitory_residents_path
    assert_response :success
  end

  test "index renders for commandant" do
    sign_in_as @commandant
    get dormitory_residents_path
    assert_response :success
  end

  test "index renders for registrar" do
    sign_in_as @registrar
    get dormitory_residents_path
    assert_response :success
  end

  test "index filters by status" do
    sign_in_as @admin
    get dormitory_residents_path, params: { status: "not_settled" }
    assert_response :success
  end

  test "index filters by gender" do
    sign_in_as @admin
    get dormitory_residents_path, params: { gender: "male" }
    assert_response :success
  end

  test "index searches by name" do
    sign_in_as @admin
    get dormitory_residents_path, params: { query: "Иванов" }
    assert_response :success
  end

  test "commandant sees only assigned buildings" do
    sign_in_as @commandant
    get dormitory_residents_path
    assert_response :success
  end

  test "show renders" do
    sign_in_as @admin
    get dormitory_resident_path(@resident)
    assert_response :success
  end

  test "show denied for commandant from unassigned building" do
    sign_in_as @commandant
    get dormitory_resident_path(@resident_unassigned)
    assert_redirected_to root_path
  end

  test "new renders" do
    sign_in_as @admin
    get new_dormitory_resident_path
    assert_response :success
  end

  test "create resident with valid params" do
    sign_in_as @admin
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW001"
        }
      }
    end
    assert_redirected_to dormitory_resident_path(Dormitory::Resident.last)
    assert_equal I18n.t("dormitory.residents.created"), flash[:notice]
  end

  test "create resident with duplicate student_ticket fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01",
          student_ticket_number: @resident.student_ticket_number
        }
      }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "Новый"
  end

  test "create resident as commandant" do
    sign_in_as @commandant
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW002"
        }
      }
    end
  end

  test "create resident as registrar" do
    sign_in_as @registrar
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW003"
        }
      }
    end
  end

  test "registrar creates resident without place when placement is unchecked even with empty room selects" do
    sign_in_as @registrar
    assert_difference "Dormitory::Resident.count", 1 do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Безместа", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "NOCHECK1",
            application_number: "З-НЧ", contract_number: "Д-НЧ",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: { place: "0" }
        }
      end
    end

    resident = Dormitory::Resident.find_by(student_ticket_number: "NOCHECK1")
    assert_redirected_to dormitory_resident_path(resident)
    assert_equal "not_settled", resident.reload.status
    assert_empty resident.accommodations.kept
  end

  test "registrar creates resident with documents" do
    sign_in_as @registrar
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW004",
          application_number: "З-777", contract_number: "Д-777",
          application_file: Rack::Test::UploadedFile.new(
            Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
          ),
          contract_file: Rack::Test::UploadedFile.new(
            Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
          )
        }
      }
    end

    resident = Dormitory::Resident.find_by(student_ticket_number: "NEW004")
    assert_equal "З-777", resident.application_number
    assert_equal "Д-777", resident.contract_number
    assert resident.application_file.attached?
    assert resident.contract_file.attached?
  end

  test "registrar cannot create resident with file but without document number" do
    sign_in_as @registrar
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW006",
          application_file: Rack::Test::UploadedFile.new(
            Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
          )
        }
      }
    end
    assert_response :unprocessable_entity
    assert_match "укажите номер заявления, если прикреплён файл", response.body
  end

  test "registrar updates resident documents" do
    sign_in_as @registrar
    resident = Dormitory::Resident.create!(
      last_name: "Док", first_name: "Студент", gender: :male, course: 1,
      date_of_birth: 20.years.ago, student_ticket_number: "NEW005"
    )

    patch dormitory_resident_path(resident), params: {
      dormitory_resident: {
        application_number: "З-888",
        contract_number: "Д-888",
        application_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        )
      }
    }

    assert_redirected_to dormitory_resident_path(resident)
    resident.reload
    assert_equal "З-888", resident.application_number
    assert_equal "Д-888", resident.contract_number
    assert resident.application_file.attached?
  end

  test "destroy denied for registrar" do
    sign_in_as @registrar
    assert_no_difference "Dormitory::Resident.kept.count" do
      delete dormitory_resident_path(@resident)
    end
    assert_redirected_to root_path
  end

  test "edit renders" do
    sign_in_as @admin
    get edit_dormitory_resident_path(@resident)
    assert_response :success
  end

  test "update resident with valid params" do
    sign_in_as @admin
    patch dormitory_resident_path(@resident), params: {
      dormitory_resident: { phone: "+79111111111" }
    }
    assert_redirected_to dormitory_resident_path(@resident)
    assert_equal "+79111111111", @resident.reload.phone
  end

  test "update gender for settled resident fails" do
    sign_in_as @admin
    patch dormitory_resident_path(@settled_resident), params: {
      dormitory_resident: { gender: "male" }
    }
    assert_response :unprocessable_entity
  end

  test "update course for not settled resident" do
    sign_in_as @admin
    patch dormitory_resident_path(@resident), params: {
      dormitory_resident: { course: "5" }
    }
    assert_redirected_to dormitory_resident_path(@resident)
    assert_equal 5, @resident.reload.course
  end

  test "update course for settled resident fails" do
    sign_in_as @admin
    patch dormitory_resident_path(@settled_resident), params: {
      dormitory_resident: { course: "5" }
    }
    assert_response :unprocessable_entity
    assert_equal 2, @settled_resident.reload.course
  end

  test "edit form shows enabled course select for not settled resident" do
    sign_in_as @admin
    get edit_dormitory_resident_path(@resident)
    assert_response :success
    assert_select "select[name='dormitory_resident[course]']" do
      assert_select "[disabled]", count: 0
    end
  end

  test "edit form shows disabled course select for settled resident" do
    sign_in_as @admin
    get edit_dormitory_resident_path(@settled_resident)
    assert_response :success
    assert_select "select[name='dormitory_resident[course]'][disabled='disabled']"
  end

  test "destroy not_settled resident" do
    sign_in_as @admin
    assert_difference "Dormitory::Resident.kept.count", -1 do
      delete dormitory_resident_path(@resident)
    end
    assert_redirected_to dormitory_residents_path
    assert @resident.reload.discarded?
  end

  test "destroy evicted resident" do
    evicted = dormitory_residents(:resident_three_evicted)
    sign_in_as @admin
    assert_difference "Dormitory::Resident.kept.count", -1 do
      delete dormitory_resident_path(evicted)
    end
  end

  test "destroy settled resident fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.kept.count" do
      delete dormitory_resident_path(@settled_resident)
    end
    assert_redirected_to dormitory_resident_path(@settled_resident)
  end

  test "destroy denied for commandant" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Resident.kept.count" do
      delete dormitory_resident_path(@resident)
    end
    assert_redirected_to root_path
  end

  test "check_ticket returns found" do
    sign_in_as @admin
    get check_ticket_dormitory_residents_path, params: { number: @resident.student_ticket_number }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["found"]
    assert_equal @resident.id, json["id"]
    assert_equal @resident.full_name, json["full_name"]
  end

  test "check_ticket returns not found" do
    sign_in_as @admin
    get check_ticket_dormitory_residents_path, params: { number: "NOTEXIST" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["found"]
  end

  test "check_ticket denied for manager" do
    sign_in_as @manager
    get check_ticket_dormitory_residents_path, params: { number: "123" }, as: :json
    assert_redirected_to root_path
  end

  test "create resident with placement issues pending accommodation into the chosen room" do
    sign_in_as @admin
    room = dormitory_rooms(:room_201)

    assert_difference "Dormitory::Resident.count", 1 do
      assert_difference "Dormitory::Accommodation.count", 1 do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Регистрант", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "NEWPLACE1",
            application_number: "З-П1", contract_number: "Д-П1",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: {
            place: "1",
            room_id: room.id,
            bed_label: "B"
          }
        }
      end
    end

    resident = Dormitory::Resident.find_by(student_ticket_number: "NEWPLACE1")
    assert_redirected_to dormitory_resident_path(resident)
    acc = resident.accommodations.kept.last
    assert_equal "pending", acc.status
    assert_equal room.id, acc.room_id
    assert_equal resident.course, acc.course
    assert_equal "B", acc.bed_label
    assert_equal 3, room.reload.current_occupancy
    assert_equal I18n.t("dormitory.residents.registered_with_place", room_number: room.number, bed_label: "B"), flash[:notice]
  end

  test "commandant selects room and bed manually during registration" do
    sign_in_as @commandant
    post dormitory_residents_path, params: {
      dormitory_resident: {
        last_name: "Новый", first_name: "Хакер", gender: "male", course: "1",
        date_of_birth: "2000-01-01", student_ticket_number: "MANUAL1",
        application_number: "З-М1", contract_number: "Д-М1",
        application_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        ),
        contract_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        )
      },
      placement: {
        place: "1",
        building_id: dormitory_buildings(:building_one).id,
        room_id: dormitory_rooms(:room_101).id,
        bed_label: "B"
      }
    }

    resident = Dormitory::Resident.find_by(student_ticket_number: "MANUAL1")
    assert resident.present?
    acc = resident.accommodations.kept.last
    assert_equal "pending", acc.status
    assert_equal dormitory_rooms(:room_101).id, acc.room_id
    assert_equal "B", acc.bed_label
  end

  test "commandant manual selection is restricted to assigned buildings" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Хакер", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "MANUAL2",
          application_number: "З-М2", contract_number: "Д-М2",
          application_file: Rack::Test::UploadedFile.new(
            Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
          ),
          contract_file: Rack::Test::UploadedFile.new(
            Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
          )
        },
        placement: {
          place: "1",
          room_id: @room_unassigned.id,
          bed_label: "A"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/resident.attributes.base.room_required")
  end

  test "commandant with placement but no room re-renders form with error" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Безместа", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "NOPLACE1"
          },
          placement: { place: "1" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/resident.attributes.base.room_required")
  end

  test "registrar selects room and bed manually during registration" do
    sign_in_as @registrar
    post dormitory_residents_path, params: {
      dormitory_resident: {
        last_name: "Новый", first_name: "Регистрант", gender: "male", course: "1",
        date_of_birth: "2000-01-01", student_ticket_number: "REGMAN1",
        application_number: "З-РМ", contract_number: "Д-РМ",
        application_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        ),
        contract_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        )
      },
      placement: {
        place: "1",
        building_id: dormitory_buildings(:building_one).id,
        room_id: dormitory_rooms(:room_101).id,
        bed_label: "C"
      }
    }

    resident = Dormitory::Resident.find_by(student_ticket_number: "REGMAN1")
    assert resident.present?
    acc = resident.accommodations.kept.last
    assert_equal "pending", acc.status
    assert_equal dormitory_rooms(:room_101).id, acc.room_id
    assert_equal "C", acc.bed_label
  end

  test "registrar with placement but no room re-renders form with error" do
    sign_in_as @registrar
    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Безместа", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "REGNOR1",
            application_number: "З-НР", contract_number: "Д-НР",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: { place: "1" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/resident.attributes.base.room_required")
  end

  test "registrar with room but no bed re-renders form with error" do
    sign_in_as @registrar
    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Безместа", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "REGBED1",
            application_number: "З-НБ", contract_number: "Д-НБ",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: {
            place: "1",
            room_id: dormitory_rooms(:room_101).id
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/resident.attributes.base.bed_required")
  end

  test "form re-render keeps placement unchecked and preserves dates" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Безместа", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: @resident.student_ticket_number
        },
        placement: { place: "0", start_date: "2026-09-01", planned_end_date: "2027-06-30" }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/type="hidden" name="placement\[place\]" id="placement_place" value="0"/, response.body)
    assert_not_includes response.body, 'checked="checked"'
    assert_match(/id="placement_start_date" value="2026-09-01"/, response.body)
    assert_match(/id="placement_planned_end_date" value="2027-06-30"/, response.body)
  end

  test "form re-render keeps posted room, bed, and dates when placement is on" do
    room = dormitory_rooms(:room_101)
    room.update_column(:gender_restriction, :female)
    sign_in_as @admin

    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Местожитель", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "CONFLICT2",
            application_number: "З-К2", contract_number: "Д-К2",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: {
            place: "1", room_id: room.id, bed_label: "A",
            start_date: "2026-09-01", planned_end_date: "2027-06-30"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, 'checked="checked"'
    assert_match(/selected="selected" value="#{room.id}"/, response.body)
    assert_includes response.body, %(value="A")
    assert_match(/id="placement_start_date" value="2026-09-01"/, response.body)
    assert_match(/id="placement_planned_end_date" value="2027-06-30"/, response.body)
  end

  test "re-rendered form keeps file inputs turbo-permanent after failed submit" do
    sign_in_as @admin
    post dormitory_residents_path, params: {
      dormitory_resident: {
        last_name: "Новый", first_name: "Человек", gender: "male", course: "1",
        date_of_birth: "2000-01-01", student_ticket_number: @resident.student_ticket_number,
        application_number: "З-Ф", contract_number: "Д-Ф",
        application_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        ),
        contract_file: Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
        )
      }
    }
    assert_response :unprocessable_entity
    assert_match(/data-turbo-permanent="true"[^>]*id="dormitory_resident_application_file"/, response.body)
    assert_match(/data-turbo-permanent="true"[^>]*id="dormitory_resident_contract_file"/, response.body)
    assert_match(/data-turbo-permanent="true"[^>]*id="dormitory_resident_photo"/, response.body)
  end

  test "registrar registers with required amount and receipt" do
    sign_in_as @registrar
    assert_difference "Dormitory::Resident.count", 1 do
      assert_difference "Dormitory::Accommodation.count", 1 do
        assert_difference "Dormitory::Receipt.kept.count", 1 do
          post dormitory_residents_path, params: {
            dormitory_resident: {
              last_name: "Новый", first_name: "Плательщик", gender: "male", course: "1",
              date_of_birth: "2000-01-01", student_ticket_number: "RECEIPT1",
              application_number: "З-Р1", contract_number: "Д-Р1",
              application_file: Rack::Test::UploadedFile.new(
                Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
              ),
              contract_file: Rack::Test::UploadedFile.new(
                Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
              )
            },
            placement: {
              place: "1", building_id: dormitory_buildings(:building_one).id,
              room_id: dormitory_rooms(:room_101).id, bed_label: "C",
              required_amount: "12000"
            },
            receipt: {
              amount: "5000",
              paid_at: Date.current.to_s,
              attachment: Rack::Test::UploadedFile.new(
                Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
              )
            }
          }
        end
      end
    end

    resident = Dormitory::Resident.find_by(student_ticket_number: "RECEIPT1")
    assert_redirected_to dormitory_resident_path(resident)
    acc = resident.accommodations.kept.last
    assert acc.pending?
    assert_equal "C", acc.bed_label
    assert_equal 12_000, acc.required_amount.to_f
    assert_equal 5_000, acc.total_paid.to_f
    receipt = acc.receipts.kept.last
    assert_equal 5_000, receipt.amount.to_f
    assert receipt.attachment.attached?
  end

  test "invalid receipt re-renders form with error and does not create the resident" do
    sign_in_as @registrar
    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Receipt.kept.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Плательщик", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "RECEIPT2",
            application_number: "З-Р2", contract_number: "Д-Р2",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: { place: "1", room_id: dormitory_rooms(:room_101).id, bed_label: "C" },
          receipt: { amount: "5000", paid_at: Date.current.to_s }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.messages.blank")
  end

  test "form re-render keeps a manually chosen building when no room was selected" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Плательщик", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: "RECEIPT-BLD"
        },
        placement: { place: "1", building_id: @building_two.id }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body,
                    %(<option selected="selected" value="#{@building_two.id}">#{@building_two.name}</option>)
    assert_match(/data-placement-form-manual-value="true"/, response.body)
  end

  test "placement disabled with receipt params creates a resident without a receipt" do
    sign_in_as @admin
    assert_difference "Dormitory::Resident.count", 1 do
      assert_no_difference "Dormitory::Accommodation.count" do
        assert_no_difference "Dormitory::Receipt.kept.count" do
          post dormitory_residents_path, params: {
            dormitory_resident: {
              last_name: "Новый", first_name: "Плательщик", gender: "male", course: "1",
              date_of_birth: "2000-01-01", student_ticket_number: "RECEIPT3"
            },
            placement: { place: "0" },
            receipt: { amount: "5000", paid_at: Date.current.to_s }
          }
        end
      end
    end
  end

  test "form re-render keeps required amount and receipt values" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Плательщик", gender: "male", course: "1",
          date_of_birth: "2000-01-01", student_ticket_number: @resident.student_ticket_number
        },
        placement: {
          place: "1", room_id: dormitory_rooms(:room_101).id, bed_label: "C",
          required_amount: "12000"
        },
        receipt: { amount: "5000", paid_at: "2026-09-01" }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/id="placement_required_amount" value="12000"/, response.body)
    assert_match(/id="receipt_amount" value="5000"/, response.body)
    assert_match(/id="receipt_paid_at" value="2026-09-01"/, response.body)
    assert_match(/id="receipt_attachment"[^>]*data-turbo-permanent="true"/, response.body)
  end

  test "create resident with manual placement into a gender-conflicting room re-renders form with state" do
    room = dormitory_rooms(:room_101)
    room.update_column(:gender_restriction, :female)
    sign_in_as @admin

    assert_no_difference "Dormitory::Resident.count" do
      assert_no_difference "Dormitory::Accommodation.count" do
        post dormitory_residents_path, params: {
          dormitory_resident: {
            last_name: "Новый", first_name: "Местожитель", gender: "male", course: "1",
            date_of_birth: "2000-01-01", student_ticket_number: "CONFLICT1",
            application_number: "З-К1", contract_number: "Д-К1",
            application_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            ),
            contract_file: Rack::Test::UploadedFile.new(
              Rails.root.join("test/fixtures/files/test.pdf"), "application/pdf"
            )
          },
          placement: { place: "1", room_id: room.id, bed_label: "A" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Новый"
    assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.gender_conflict")
  end

  test "preview_place returns room and bed" do
    sign_in_as @admin
    get preview_place_dormitory_residents_path, params: { gender: "male", course: "1" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal dormitory_rooms(:room_201).id, json["room_id"]
    assert_equal dormitory_buildings(:building_one).id, json["building_id"]
    assert_equal "B", json["bed_label"]
  end

  test "preview_place suggests rooms within the commandant building scope" do
    sign_in_as @commandant
    get preview_place_dormitory_residents_path, params: { gender: "male", course: "1" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal dormitory_rooms(:room_201).id, json["room_id"]
    assert_equal "B", json["bed_label"]
  end

  test "commandant new resident form lists rooms within assigned buildings" do
    sign_in_as @commandant

    get new_dormitory_resident_path

    assert_response :success
    assert_includes response.body, dormitory_rooms(:room_101).id.to_s
    assert_not_includes response.body, @room_unassigned.id.to_s
  end

  test "commandant new resident form does not leak rooms outside assigned buildings when no suggestion exists" do
    Dormitory::Room.where(building: [ @building, @building_two ]).update_all(
      status: :fully_occupied, current_occupancy: 2
    )
    sign_in_as @commandant

    get new_dormitory_resident_path

    assert_response :success
    assert_not_includes response.body, @room_unassigned.id.to_s
  end

  test "preview_place works for registrar" do
    sign_in_as @registrar
    get preview_place_dormitory_residents_path, params: { gender: "male", course: "1" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal dormitory_rooms(:room_201).id, json["room_id"]
  end

  test "preview_place returns no room when none available" do
    sign_in_as @admin
    Dormitory::Room.update_all(status: :fully_occupied)
    get preview_place_dormitory_residents_path, params: { gender: "male", course: "1" }, as: :json
    assert_response :success
    assert_nil JSON.parse(response.body)["room_id"]
  end

  test "preview_place denied for manager" do
    sign_in_as @manager
    get preview_place_dormitory_residents_path, params: { gender: "male", course: "1" }, as: :json
    assert_redirected_to root_path
  end
end
