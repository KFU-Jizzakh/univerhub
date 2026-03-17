require "csv"

module Dormitory
  class ExportService
    # PURPOSE: Generates 4 types of CSV exports (settled residents, free slots, accommodation history, occupancy stats) with UTF-8 BOM and semicolon delimiter
    # SPECIFICATION: SPEC-DORM-06
    SEPARATOR = ";"

    def self.settled_residents_csv(scope, filters = {})
      residents = scope.kept
        .where(status: [ :settled, :temporarily_absent ])
        .joins(current_room: :building)
        .includes(current_room: :building, active_accommodation: :academic_year)
        .order("dormitory_buildings.name", "dormitory_rooms.floor", "dormitory_rooms.number",
               "dormitory_residents.last_name", "dormitory_residents.first_name")

      residents = apply_building_filter(residents, filters[:building_id])
      residents = apply_floor_filter(residents, filters[:floor])
      residents = apply_room_filter(residents, filters[:room_id])
      residents = apply_academic_year_filter_accommodations(residents, filters[:academic_year_id])

      generate_csv([ "ФИО", "Пол", "Дата рождения", "№ студ. билета", "Телефон", "Email",
                     "Корпус", "Этаж", "Комната", "Дата заселения", "№ заявки", "№ договора" ]) do |csv|
        residents.find_each do |resident|
          acc = resident.active_accommodation
          next unless acc

          csv << [
            resident.full_name,
            I18n.t("dormitory.resident.gender.#{resident.gender}"),
            resident.date_of_birth,
            resident.student_ticket_number,
            resident.phone,
            resident.email,
            resident.current_room&.building&.name,
            resident.current_room&.floor,
            resident.current_room&.number,
            acc.start_date,
            acc.application_number,
            acc.contract_number
          ]
        end
      end
    end

    def self.free_slots_csv(scope, filters = {})
      rooms = scope.kept
        .includes(:building)
        .order("dormitory_buildings.name", :floor, :number)

      rooms = rooms.where(building_id: filters[:building_id]) if filters[:building_id].present?

      generate_csv([ "Корпус", "Этаж", "Комната", "Вместимость", "Занято", "Свободно",
                     "Ограничение по полу", "Статус" ]) do |csv|
        rooms.find_each do |room|
          csv << [
            room.building.name,
            room.floor,
            room.number,
            room.capacity,
            room.current_occupancy,
            room.available_slots,
            room.gender_restriction ? I18n.t("dormitory.resident.gender.#{room.gender_restriction}") : "—",
            I18n.t("dormitory.room.status.#{room.status}")
          ]
        end
      end
    end

    def self.history_csv(scope, filters = {})
      accommodations = scope.kept
        .includes(:resident, room: :building)
        .order("dormitory_buildings.name", "dormitory_rooms.floor", "dormitory_rooms.number",
               "dormitory_accommodations.start_date")

      accommodations = apply_building_filter_history(accommodations, filters[:building_id])
      accommodations = accommodations.where(status: filters[:status]) if filters[:status].present?
      accommodations = accommodations.where("start_date >= ?", filters[:date_from]) if filters[:date_from].present?
      accommodations = accommodations.where("start_date <= ?", filters[:date_to]) if filters[:date_to].present?
      accommodations = apply_academic_year_filter_direct(accommodations, filters[:academic_year_id])

      generate_csv([ "ФИО резидента", "№ студ. билета", "Корпус", "Этаж", "Комната",
                     "№ заявки", "№ договора", "Дата начала", "Дата окончания", "Дней", "Статус",
                     "Причина выселения", "Комментарий" ]) do |csv|
        accommodations.find_each do |acc|
          csv << [
            acc.resident.full_name,
            acc.resident.student_ticket_number,
            acc.room.building.name,
            acc.room.floor,
            acc.room.number,
            acc.application_number,
            acc.contract_number,
            acc.start_date,
            acc.actual_end_date || "—",
            acc.actual_duration_days || acc.planned_duration_days,
            I18n.t("statuses.#{acc.status}"),
            acc.eviction_reason ? I18n.t("eviction_reasons.#{acc.eviction_reason}") : "—",
            acc.comment
          ]
        end
      end
    end

    def self.occupancy_stats_csv(scope)
      buildings = scope.kept.includes(:rooms).order(:name)

      generate_csv([ "Корпус", "Этаж", "Всего комнат", "Свободных", "Частично занятых",
                     "Полностью занятых", "Переполненных", "Вместимость",
                     "Занято", "% заселённости" ]) do |csv|
        grand_rooms = 0
        grand_free = 0
        grand_partial = 0
        grand_full = 0
        grand_over = 0
        grand_cap = 0
        grand_occ = 0

        buildings.each do |building|
          b_rooms = 0; b_free = 0; b_partial = 0; b_full = 0; b_over = 0
          b_cap = 0; b_occ = 0

          building.rooms.kept.group_by(&:floor).sort.each do |floor, rooms|
            f_rooms = rooms.size
            f_free = rooms.count { |r| r.free? }
            f_partial = rooms.count { |r| r.partially_occupied? }
            f_full = rooms.count { |r| r.fully_occupied? }
            f_over = rooms.count { |r| r.overcrowded? }
            f_cap = rooms.sum(&:capacity)
            f_occ = rooms.sum(&:current_occupancy)
            rate = f_cap.positive? ? (f_occ.to_f / f_cap * 100).round(1) : 0

            csv << [ building.name, floor, f_rooms, f_free, f_partial, f_full, f_over, f_cap, f_occ, rate ]

            b_rooms += f_rooms; b_free += f_free; b_partial += f_partial; b_full += f_full
            b_over += f_over; b_cap += f_cap; b_occ += f_occ
          end

          rate = b_cap.positive? ? (b_occ.to_f / b_cap * 100).round(1) : 0
          csv << [ "Итого #{building.name}", "—", b_rooms, b_free, b_partial, b_full, b_over, b_cap, b_occ, rate ]

          grand_rooms += b_rooms; grand_free += b_free; grand_partial += b_partial; grand_full += b_full
          grand_over += b_over; grand_cap += b_cap; grand_occ += b_occ
        end

        if buildings.size > 1
          rate = grand_cap.positive? ? (grand_occ.to_f / grand_cap * 100).round(1) : 0
          csv << [ "ИТОГО", "—", grand_rooms, grand_free, grand_partial, grand_full, grand_over,
                   grand_cap, grand_occ, rate ]
        end
      end
    end

    # Generate CSV with UTF-8 BOM for Excel compatibility
    def self.generate_csv(headers)
      bom = "\uFEFF"
      CSV.generate(col_sep: SEPARATOR) do |csv|
        first, *rest = headers
        csv << [ bom + first.to_s ] + rest
        yield csv
      end
    end
    private_class_method :generate_csv

    def self.apply_building_filter(residents, building_id)
      return residents unless building_id.present?

      residents.where(current_room: { building_id: building_id })
    end
    private_class_method :apply_building_filter

    def self.apply_floor_filter(residents, floor)
      return residents unless floor.present?

      residents.where(current_room: { floor: floor })
    end
    private_class_method :apply_floor_filter

    def self.apply_room_filter(residents, room_id)
      return residents unless room_id.present?

      residents.where(current_room_id: room_id)
    end
    private_class_method :apply_room_filter

    def self.apply_academic_year_filter_accommodations(residents, academic_year_id)
      return residents unless academic_year_id.present?

      residents.joins(:active_accommodation)
               .where(dormitory_accommodations: { academic_year_id: academic_year_id })
    end
    private_class_method :apply_academic_year_filter_accommodations

    def self.apply_building_filter_history(accommodations, building_id)
      return accommodations unless building_id.present?

      accommodations.joins(:room).where(dormitory_rooms: { building_id: building_id })
    end
    private_class_method :apply_building_filter_history

    def self.apply_academic_year_filter_direct(accommodations, academic_year_id)
      return accommodations unless academic_year_id.present?

      accommodations.where(academic_year_id: academic_year_id)
    end
    private_class_method :apply_academic_year_filter_direct
  end
end
