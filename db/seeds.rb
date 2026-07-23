# Роли
Role::NAMES.each do |role_name|
  Role.find_or_create_by!(name: role_name)
end
puts "Roles: #{Role.pluck(:name).join(', ')}"

if Rails.env.production?
  password = SecureRandom.hex(16)
  admin = User.find_or_create_by!(email_address: "admin@univerhub.local") do |u|
    u.password = password
    u.password_confirmation = password
  end

  if admin.previously_new_record?
    puts "Admin created: admin@univerhub.local / #{password}"
  else
    puts "Admin already exists, password unchanged"
  end

  role = Role.find_by!(name: "admin")
  UserRole.find_or_create_by!(user: admin, role: role)

  admin.create_profile!(
    first_name: "Системный",
    middle_name: "Админович",
    last_name: "Администратор",
    summary: "Администратор платформы UniverHub"
  ) unless admin.profile

  Current.session = admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  t4 = Reporting::ReportTemplate.find_or_create_by!(name: "Отчёт о работе тютора") do |t|
    t.description = "Ежеквартальный отчёт тютора о воспитательной работе с студентами"
    t.creator = admin
  end

  [
    { name: "Нормативно-правовая осведомлённость", description: "a) Осведомлённость тютора о действующих законодательных актах, «Кодексе этики» вуза, правилах внутреннего распорядка и иных внутренних документах;\nb) Ознакомление студентов с действующими законодательными актами, «Кодексом этики» вуза, правилами внутреннего распорядка и иными внутренними документами.", position: 1, max_grade: 5, attachments_required: false },
    { name: "Организация внеучебного времени студентов", description: "a) Информирование студентов о существующих кружках, Информационном ресурсном центре и их привлечение;\nb) Проведение индивидуальных и групповых консультаций по развитию личных и профессиональных интересов студентов;\nc) Привлечение студентов в литературные, спортивные, художественные, культурные и профориентационные кружки вблизи вуза;\nd) Организация посещений студентами театров, музеев и иных досуговых учреждений.", position: 2, max_grade: 5, attachments_required: false },
    { name: "Духовно-просветительские мероприятия и конкурсы", description: "a) Активность и инициатива в культурных, научно-творческих, спортивных и иных духовно-просветительских мероприятиях (встречи, круглые столы);\nb) Активность и инициатива в праздничных мероприятиях, посвящённых национальным праздникам, важным датам и дням исторической памяти;\nc) Активность в пропаганде конкурсов, фестивалей и олимпиад, а также в привлечении студентов.", position: 3, max_grade: 5, attachments_required: false },
    { name: "Профилактика правонарушений и преступности", description: "a) Проведение пропагандистской работы по профилактике коррупции, наркомании, употребления психотропных веществ, торговли людьми и иных негативных явлений;\nb) Обеспечение участия студентов в мероприятиях по профилактике правонарушений, наркомании и преступности;\nc) Ведение постоянной разъяснительной работы со студентами, склонными к правонарушениям, дисциплинарным проступкам или иным негативным проявлениям.", position: 4, max_grade: 5, attachments_required: false },
    { name: "Обеспечение жильём и мониторинг условий проживания", description: "a) Формирование и обновление данных о студентах, проживающих в общежитии, на съёмном жилье, в частном жилье или у близких родственников;\nb) Формирование базы съёмного жилья (резерв) в течение учебного года;\nc) Мониторинг условий проживания студентов, устранение существующих проблем или информирование ответственных лиц.", position: 5, max_grade: 5, attachments_required: false },
    { name: "Сотрудничество с махалля и родителями", description: "a) Установление связи с родителями, организация родительских собраний (онлайн или офлайн) и работа с проблемными студентами;\nb) Инициатива и активность в сотрудничестве с махалля, инспектором по профилактике и общественностью;\nc) Работа со студентами, нуждающимися в социальной защите и поддержке.", position: 6, max_grade: 5, attachments_required: false }
  ].each do |attrs|
      t4.items.find_or_create_by!(name: attrs[:name]) do |item|
        item.assign_attributes(attrs)
      end
    end

  t4.published! if t4.draft?
  puts "Template '#{t4.name}': #{t4.status}, #{t4.items.count} items"

  puts "\n=== Seed complete ==="
else

  # Пользователи
  users = {}

  {
    admin: "admin@univerhub.local",
    manager: "manager@univerhub.local",
    reporter1: "ivanov@univerhub.local",
    reporter2: "petrova@univerhub.local",
    reviewer: "reviewer@univerhub.local",
    supervisor: "supervisor@univerhub.local",
    visitor: "visitor@univerhub.local",
    reporting_admin: "reporting.admin@univerhub.local",
    dormitory_admin: "dormitory.admin@univerhub.local",
    dormitory_commandant: "commandant@univerhub.local"
  }.each do |key, email|
      users[key] = User.find_or_create_by!(email_address: email) do |u|
        u.password = "password"
        u.password_confirmation = "password"
      end
    end
  puts "Users: #{User.count}"

  # Назначение ролей
  {
    admin:           %w[admin],
    manager:         %w[reporting.manager],
    reporter1:       %w[reporting.reporter],
    reporter2:       %w[reporting.reporter],
    reviewer:        %w[reporting.reviewer],
    supervisor:      %w[supervisor],
    visitor:         %w[reporting.visitor],
    reporting_admin: %w[reporting.admin],
    dormitory_admin: %w[dormitory.admin],
    dormitory_commandant: %w[dormitory.commandant]
  }.each do |key, role_names|
      user = users[key]
      role_names.each do |rn|
        role = Role.find_by!(name: rn)
        UserRole.find_or_create_by!(user: user, role: role)
      end
    end
  puts "Roles assigned"

  # Профили пользователей
  {
    admin:                 { first_name: "Системный", middle_name: "Админович", last_name: "Администратор", summary: "Администратор платформы UniverHub" },
    manager:               { first_name: "Мария", middle_name: "Ивановна", last_name: "Сидорова", summary: "Руководитель отдела отчётности кафедры информатики" },
    reporter1:             { first_name: "Алексей", middle_name: "Петрович", last_name: "Иванов", summary: "Доцент кафедры информатики, к.т.н." },
    reporter2:             { first_name: "Елена", middle_name: "Сергеевна", last_name: "Петрова", summary: "Старший преподаватель кафедры математики" },
    reviewer:              { first_name: "Дмитрий", middle_name: "Александрович", last_name: "Козлов", summary: "Профессор, заведующий кафедрой информатики, д.т.н." },
    supervisor:            { first_name: "Ольга", middle_name: "Николаевна", last_name: "Волкова", summary: "Проректор по учебной работе" },
    visitor:               { first_name: "Наталья", middle_name: "Андреевна", last_name: "Морозова", summary: "Представитель учебно-методического управления" },
    reporting_admin:       { first_name: "Виктор", middle_name: "Дмитриевич", last_name: "Борисов", summary: "Администратор модуля отчётности" },
    dormitory_admin:       { first_name: "Андрей", middle_name: "Сергеевич", last_name: "Кузнецов", summary: "Администратор модуля общежития" },
    dormitory_commandant:  { first_name: "Светлана", middle_name: "Викторовна", last_name: "Новикова", summary: "Комендант общежития" }
  }.each do |key, attrs|
      user = users[key]
      user.create_profile!(attrs) unless user.profile
    end
  puts "Profiles: #{UserProfile.count}"

  # Подставляем Current.user для Trackable
  Current.session = users[:manager].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  # Шаблон 1: Научная деятельность
  t1 = Reporting::ReportTemplate.find_or_create_by!(name: "Отчёт о научной деятельности") do |t|
    t.description = "Ежегодный отчёт преподавателя о научно-исследовательской работе"
    t.creator = users[:manager]
  end

  [
    { name: "Публикации", description: "Список научных публикаций за отчётный период", position: 1, max_grade: 25, attachments_required: true },
    { name: "Конференции", description: "Участие в научных конференциях и семинарах", position: 2, max_grade: 25, attachments_required: false },
    { name: "Гранты и проекты", description: "Участие в грантовых программах и научных проектах", position: 3, max_grade: 25, attachments_required: true },
    { name: "Руководство студентами", description: "Научное руководство курсовыми и дипломными работами", position: 4, max_grade: 25, attachments_required: false }
  ].each do |attrs|
      t1.items.find_or_create_by!(name: attrs[:name]) do |item|
        item.assign_attributes(attrs)
      end
    end

  t1.published! if t1.draft?
  puts "Template '#{t1.name}': #{t1.status}, #{t1.items.count} items"

  # Шаблон 2: Учебно-методическая работа
  t2 = Reporting::ReportTemplate.find_or_create_by!(name: "Отчёт по учебно-методической работе") do |t|
    t.description = "Отчёт о разработке учебных материалов и методических пособий"
    t.creator = users[:manager]
  end

  [
    { name: "Разработка курсов", description: "Новые или обновлённые учебные курсы", position: 1, max_grade: 30, attachments_required: false },
    { name: "Методические пособия", description: "Изданные методические материалы", position: 2, max_grade: 30, attachments_required: true },
    { name: "Повышение квалификации", description: "Пройденные курсы и сертификаты", position: 3, max_grade: 30, attachments_required: true }
  ].each do |attrs|
      t2.items.find_or_create_by!(name: attrs[:name]) do |item|
        item.assign_attributes(attrs)
      end
    end

  t2.published! if t2.draft?
  puts "Template '#{t2.name}': #{t2.status}, #{t2.items.count} items"

  # Шаблон 3: черновик
  t3 = Reporting::ReportTemplate.find_or_create_by!(name: "Отчёт о воспитательной работе") do |t|
    t.description = "Отчёт куратора о воспитательной работе в группе"
    t.creator = users[:manager]
  end

  [
    { name: "Мероприятия", description: "Проведённые воспитательные мероприятия", position: 1, attachments_required: false },
    { name: "Работа с родителями", description: "Встречи и консультации с родителями", position: 2, attachments_required: false }
  ].each do |attrs|
      t3.items.find_or_create_by!(name: attrs[:name]) do |item|
        item.assign_attributes(attrs)
      end
    end
  puts "Template '#{t3.name}': #{t3.status} (draft), #{t3.items.count} items"

  # Шаблон 4: Отчёт тютора (ежеквартальный)
  t4 = Reporting::ReportTemplate.find_or_create_by!(name: "Отчёт о работе тютора") do |t|
    t.description = "Ежеквартальный отчёт тютора о воспитательной работе с студентами"
    t.creator = users[:manager]
  end

  [
    { name: "Нормативно-правовая осведомлённость", description: "a) Осведомлённость тютора о действующих законодательных актах, «Кодексе этики» вуза, правилах внутреннего распорядка и иных внутренних документах;\nb) Ознакомление студентов с действующими законодательными актами, «Кодексом этики» вуза, правилами внутреннего распорядка и иными внутренними документами.", position: 1, max_grade: 5, attachments_required: false },
    { name: "Организация внеучебного времени студентов", description: "a) Информирование студентов о существующих кружках, Информационном ресурсном центре и их привлечение;\nb) Проведение индивидуальных и групповых консультаций по развитию личных и профессиональных интересов студентов;\nc) Привлечение студентов в литературные, спортивные, художественные, культурные и профориентационные кружки вблизи вуза;\nd) Организация посещений студентами театров, музеев и иных досуговых учреждений.", position: 2, max_grade: 5, attachments_required: false },
    { name: "Духовно-просветительские мероприятия и конкурсы", description: "a) Активность и инициатива в культурных, научно-творческих, спортивных и иных духовно-просветительских мероприятиях (встречи, круглые столы);\nb) Активность и инициатива в праздничных мероприятиях, посвящённых национальным праздникам, важным датам и дням исторической памяти;\nc) Активность в пропаганде конкурсов, фестивалей и олимпиад, а также в привлечении студентов.", position: 3, max_grade: 5, attachments_required: false },
    { name: "Профилактика правонаруждений и преступности", description: "a) Проведение пропагандистской работы по профилактике коррупции, наркомании, употребления психотропных веществ, торговли людьми и иных негативных явлений;\nb) Обеспечение участия студентов в мероприятиях по профилактике правонарушений, наркомании и преступности;\nc) Ведение постоянной разъяснительной работы со студентами, склонными к правонарушениям, дисциплинарным проступкам или иным негативным проявлениям.", position: 4, max_grade: 5, attachments_required: false },
    { name: "Обеспечение жильём и мониторинг условий проживания", description: "a) Формирование и обновление данных о студентах, проживающих в общежитии, на съёмном жилье, в частном жилье или у близких родственников;\nb) Формирование базы съёмного жилья (резерв) в течение учебного года;\nc) Мониторинг условий проживания студентов, устранение существующих проблем или информирование ответственных лиц.", position: 5, max_grade: 5, attachments_required: false },
    { name: "Сотрудничество с махалля и родителями", description: "a) Установление связи с родителями, организация родительских собраний (онлайн или офлайн) и работа с проблемными студентами;\nb) Инициатива и активность в сотрудничестве с махалля, инспектором по профилактике и общественностью;\nc) Работа со студентами, нуждающимися в социальной защите и поддержке.", position: 6, max_grade: 5, attachments_required: false }
  ].each do |attrs|
      t4.items.find_or_create_by!(name: attrs[:name]) do |item|
        item.assign_attributes(attrs)
      end
    end

  t4.published! if t4.draft?
  puts "Template '#{t4.name}': #{t4.status}, #{t4.items.count} items"

  # Отчёт 1: принятый
  r1 = Reporting::Report.find_or_create_by!(name: "Научная деятельность — Иванов, 2025") do |r|
    r.description = "Годовой отчёт Иванова о научной деятельности за 2025 год"
    r.creator = users[:manager]
    r.reporter = users[:reporter1]
    r.reviewer = users[:reviewer]
    r.deadline = 2.weeks.from_now
  end

  if r1.report_items.empty?
    t1.items.ordered.each do |ti|
      r1.report_items.create!(name: ti.name, description: ti.description, attachments_required: ti.attachments_required, max_grade: ti.max_grade)
    end
  end

  if r1.draft?
    r1.publish!
    r1.take_in_progress!
    r1.report_items.each_with_index do |item, i|
      item.update!(content: "Содержание пункта «#{item.name}» заполнено.")
      if item.attachments_required?
        item.attachments.attach(io: StringIO.new("Пример содержимого файла"), filename: "#{item.name.parameterize}.txt", content_type: "text/plain")
      end
    end
    r1.submit!
    r1.report_items.each_with_index do |item, i|
      item.update!(grade: 20 + i, grade_comment: "Хорошая работа")
    end
    r1.total_grade = r1.report_items.sum(:grade)
    r1.accept!
  end
  puts "Report '#{r1.name}': #{r1.status}, grade: #{r1.total_grade}"

  # Отчёт 2: на проверке
  r2 = Reporting::Report.find_or_create_by!(name: "Методическая работа — Петрова, 2025") do |r|
    r.description = "Отчёт Петровой по учебно-методической работе"
    r.creator = users[:manager]
    r.reporter = users[:reporter2]
    r.reviewer = users[:reviewer]
    r.deadline = 1.month.from_now
  end

  if r2.report_items.empty?
    t2.items.ordered.each do |ti|
      r2.report_items.create!(name: ti.name, description: ti.description, attachments_required: ti.attachments_required, max_grade: ti.max_grade)
    end
  end

  if r2.draft?
    r2.publish!
    r2.take_in_progress!
    r2.report_items.each do |item|
      item.update!(content: "Заполнено: #{item.name}")
      if item.attachments_required?
        item.attachments.attach(io: StringIO.new("Пример содержимого файла"), filename: "#{item.name.parameterize}.txt", content_type: "text/plain")
      end
    end
    r2.submit!
  end
  puts "Report '#{r2.name}': #{r2.status}"

  # Отчёт 3: новый, назначен
  r3 = Reporting::Report.find_or_create_by!(name: "Научная деятельность — Петрова, 2025") do |r|
    r.description = "Годовой отчёт Петровой о научной деятельности"
    r.creator = users[:manager]
    r.reporter = users[:reporter2]
    r.reviewer = users[:reviewer]
    r.deadline = 3.weeks.from_now
  end

  if r3.report_items.empty?
    t1.items.ordered.each do |ti|
      r3.report_items.create!(name: ti.name, description: ti.description, attachments_required: ti.attachments_required, max_grade: ti.max_grade)
    end
  end

  r3.publish! if r3.draft?
  puts "Report '#{r3.name}': #{r3.status}"

  # Отчёт 4: черновик
  r4 = Reporting::Report.find_or_create_by!(name: "Методическая работа — Иванов, 2025") do |r|
    r.description = "Отчёт Иванова по учебно-методической работе"
    r.creator = users[:manager]
    r.reporter = users[:reporter1]
    r.reviewer = users[:reviewer]
    r.deadline = 2.months.from_now
  end

  if r4.report_items.empty?
    t2.items.ordered.each do |ti|
      r4.report_items.create!(name: ti.name, description: ti.description, attachments_required: ti.attachments_required, max_grade: ti.max_grade)
    end
  end
  puts "Report '#{r4.name}': #{r4.status} (draft)"

  # Уведомления
  Notification.find_or_create_by!(recipient: users[:reporter2], notifiable: r2, action: "reporting.report.assigned")
  Notification.find_or_create_by!(recipient: users[:reviewer], notifiable: r2, action: "reporting.report.submitted")
  Notification.find_or_create_by!(recipient: users[:reporter1], notifiable: r1, action: "reporting.report.accepted") do |n|
    n.read_at = 1.day.ago
  end
  Notification.find_or_create_by!(recipient: users[:reporter2], notifiable: r3, action: "reporting.report.assigned")
  puts "Notifications: #{Notification.count}"

  # =============================================================================
  # Модуль «Общежитие»
  # =============================================================================

  # Корпуса и комнаты создаёт администратор общежития
  Current.session = users[:dormitory_admin].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  # Корпуса
  buildings = {}

  {
    building_one: { name: "Корпус 1", address: "ул. Университетская, 1", floors_count: 5, description: "Основной корпус общежития" },
    building_two: { name: "Корпус 2", address: "ул. Университетская, 3", floors_count: 3, description: "Второй корпус общежития" }
  }.each do |key, attrs|
      buildings[key] = Dormitory::Building.find_or_create_by!(name: attrs[:name]) do |b|
        b.assign_attributes(attrs.except(:name))
      end
    end
  puts "Buildings: #{Dormitory::Building.count}"

  # Учебные годы
  academic_years = {}
  {
    active_2025_2026: { name: "2025/2026", start_date: Date.new(2025, 9, 1), end_date: Date.new(2026, 8, 31), status: :active },
    pending_2026_2027: { name: "2026/2027", start_date: Date.new(2026, 9, 1), end_date: Date.new(2027, 8, 31), status: :pending }
  }.each do |key, attrs|
      year = Dormitory::AcademicYear.find_or_create_by!(name: attrs[:name]) do |y|
        y.assign_attributes(attrs.except(:name))
      end
      year.do_activate! if year.pending? && attrs[:status] == :active
      academic_years[key] = year
    end
  puts "AcademicYears: #{Dormitory::AcademicYear.count}"

  # Комнаты
  rooms = {}

  [
    { key: :room_101, number: "101", building: buildings[:building_one], floor: 1, capacity: 3, gender_restriction: :male },
    { key: :room_102, number: "102", building: buildings[:building_one], floor: 1, capacity: 2, gender_restriction: :male },
    { key: :room_201, number: "201", building: buildings[:building_one], floor: 2, capacity: 4 },
    { key: :room_202, number: "202", building: buildings[:building_one], floor: 2, capacity: 2, gender_restriction: :female },
    { key: :room_301, number: "301", building: buildings[:building_one], floor: 3, capacity: 3, status: :free },
    { key: :room_b1_101, number: "101", building: buildings[:building_two], floor: 1, capacity: 2, gender_restriction: :female },
    { key: :room_b1_102, number: "102", building: buildings[:building_two], floor: 1, capacity: 3 }
  ].each do |attrs|
      rooms[attrs[:key]] = Dormitory::Room.find_or_create_by!(
        number: attrs[:number], building: attrs[:building]
      ) do |r|
          r.floor = attrs[:floor]
          r.capacity = attrs[:capacity]
          r.current_occupancy = 0
          r.gender_restriction = attrs[:gender_restriction]
          r.status = attrs[:status] || :free
        end
    end
  puts "Rooms: #{Dormitory::Room.count}"

  # Назначение корпусов коменданту
  buildings.each_value do |b|
    Dormitory::CommandantBuilding.find_or_create_by!(user: users[:dormitory_commandant], building: b)
  end
  puts "CommandantBuildings: #{Dormitory::CommandantBuilding.count}"

  # Проживающих регистрирует комендант
  Current.session = users[:dormitory_commandant].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  # Проживающие
  residents = {}

  [
    { key: :ivanov,     last_name: "Иванов",    first_name: "Иван",      middle_name: "Иванович",     gender: :male,   student_ticket_number: "АБ123456", phone: "+79001234567", email: "ivanov@student.univer.local" },
    { key: :petrova,    last_name: "Петрова",   first_name: "Мария",    middle_name: "Сергеевна",    gender: :female, student_ticket_number: "ВГ789012", phone: "+79002345678", email: "petrova@student.univer.local" },
    { key: :sidorov,    last_name: "Сидоров",   first_name: "Алексей",  middle_name: nil,            gender: :male,   student_ticket_number: "ДЖ345678", phone: "+79003456789" },
    { key: :kozlova,    last_name: "Козлова",   first_name: "Анна",     middle_name: "Петровна",     gender: :female, student_ticket_number: "ЕИ901234", phone: "+79004567890", email: "kozlova@student.univer.local" },
    { key: :smirnov,    last_name: "Смирнов",   first_name: "Дмитрий",  middle_name: "Олегович",     gender: :male,   student_ticket_number: "ЖИ567890" },
    { key: :volkova,    last_name: "Волкова",   first_name: "Елена",    middle_name: "Александровна", gender: :female, student_ticket_number: "ЗИ135790", phone: "+79006789012" },
    { key: :novikov,    last_name: "Новиков",   first_name: "Павел",    middle_name: "Андреевич",    gender: :male,   student_ticket_number: "КЛ246801", phone: "+79007890123" },
    { key: :fedorova,   last_name: "Фёдорова",  first_name: "Ольга",    middle_name: "Дмитриевна",   gender: :female, student_ticket_number: "МН357911", email: "fedorova@student.univer.local" }
  ].each do |attrs|
      residents[attrs[:key]] = Dormitory::Resident.find_or_create_by!(
        student_ticket_number: attrs[:student_ticket_number]
      ) do |r|
          r.assign_attributes(attrs.except(:key, :student_ticket_number))
          r.date_of_birth = 20.years.ago.to_date
          r.status = :not_settled
        end
    end
  puts "Residents: #{Dormitory::Resident.count}"

  # Заселение проживающих — выполняет комендант
  def seed_file(io: StringIO.new("seed document"), filename:, content_type: "application/pdf")
    { io: io, filename: filename, content_type: content_type }
  end

  accommodations = {}

  [
    { key: :acc_petrova_201,  resident: :petrova, room: :room_201, app_num: "З-001", contract_num: "Д-001", comment: "Заселение по приказу №123" },
    { key: :acc_sidorov_201,  resident: :sidorov, room: :room_201, app_num: "З-002", contract_num: "Д-002", comment: nil },
    { key: :acc_smirnov_102,  resident: :smirnov, room: :room_102, app_num: "З-003", contract_num: "Д-003", comment: nil },
    { key: :acc_kozlova_b101, resident: :kozlova, room: :room_b1_101, app_num: "З-004", contract_num: "Д-004", comment: "Перевод из другого общежития" },
    { key: :acc_volkova_202,  resident: :volkova, room: :room_202, app_num: "З-005", contract_num: "Д-005", comment: nil },
    { key: :acc_novikov_102,  resident: :novikov, room: :room_102, app_num: "З-008", contract_num: "Д-008", comment: nil },
    { key: :acc_fedorova_202, resident: :fedorova, room: :room_202, app_num: "З-009", contract_num: "Д-009", comment: nil }
  ].each do |attrs|
      resident = residents[attrs[:resident]]
      room = rooms[attrs[:room]]

      existing = Dormitory::Accommodation.kept.find_by(resident: resident, status: :active)
      if existing
        accommodations[attrs[:key]] = existing
        next
      end

      acc = Dormitory::Accommodation.new(
        resident: resident,
        room: room,
        application_number: attrs[:app_num],
        contract_number: attrs[:contract_num],
        start_date: Date.current,
        planned_end_date: Date.current + 1.year,
        comment: attrs[:comment]
      )
      acc.application_file.attach(seed_file(filename: "application_#{attrs[:app_num]}.pdf"))
      acc.contract_file.attach(seed_file(filename: "contract_#{attrs[:contract_num]}.pdf"))
      acc.receipts.build(
        amount: 1, paid_at: Date.current,
        attachment: seed_file(filename: "receipt_#{attrs[:app_num]}.pdf")
      )

      acc.do_settle!
      accommodations[attrs[:key]] = acc
    rescue ActiveRecord::RecordInvalid
      puts "  WARNING: Could not settle #{resident&.full_name} into room #{room&.number}: #{acc&.errors&.full_messages&.join(', ')}"
    end
  puts "Active accommodations: #{Dormitory::Accommodation.where(status: :active).count}"

  # Переселение Иванова из room_101 в room_b1_102 (другой корпус)
  # Сначала заселим Иванова в room_101
  acc_ivanov = Dormitory::Accommodation.kept.find_by(resident: residents[:ivanov], status: :active)
  unless acc_ivanov
    acc_ivanov = Dormitory::Accommodation.new(
      resident: residents[:ivanov],
      room: rooms[:room_101],
      application_number: "З-006",
      contract_number: "Д-006",
      start_date: 1.week.ago.to_date,
      planned_end_date: 1.week.ago.to_date + 1.year,
      comment: "Первичное заселение"
    )
    acc_ivanov.application_file.attach(seed_file(filename: "application_З-006.pdf"))
    acc_ivanov.contract_file.attach(seed_file(filename: "contract_Д-006.pdf"))
    acc_ivanov.receipts.build(
      amount: 1, paid_at: Date.current,
      attachment: seed_file(filename: "receipt_З-006.pdf")
    )
    acc_ivanov.do_settle!
    puts "  Settled #{residents[:ivanov].full_name} in room #{rooms[:room_101].number}"
  end

  # Переселение выполняет администратор общежития
  Current.session = users[:dormitory_admin].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  if acc_ivanov.active?
    begin
      new_acc = Dormitory::Accommodation.new(
        resident: residents[:ivanov],
        room: rooms[:room_b1_102],
        application_number: "З-007",
        contract_number: "Д-007",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year,
        comment: "Переселение по личной просьбе"
      )
      new_acc.application_file.attach(seed_file(filename: "application_З-007.pdf"))
      new_acc.contract_file.attach(seed_file(filename: "contract_Д-007.pdf"))
      new_acc.receipts.build(
        amount: 1, paid_at: Date.current,
        attachment: seed_file(filename: "receipt_З-007.pdf")
      )
      acc_ivanov.do_transfer!(new_acc, eviction_reason: "transfer")
      puts "  Transferred #{residents[:ivanov].full_name}: #{rooms[:room_101].number} → #{rooms[:room_b1_102].number}"
    rescue ActiveRecord::RecordInvalid => e
      puts "  WARNING: Transfer failed for #{residents[:ivanov].full_name}: #{e.message}"
    end
  end

  # Выселение Смирнова — выполняет комендант
  Current.session = users[:dormitory_commandant].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  acc_smirnov = accommodations[:acc_smirnov_102]
  if acc_smirnov&.active?
    begin
      acc_smirnov.do_evict!(eviction_reason: "graduation", comment: "Успешное окончание университета")
      puts "  Evicted #{residents[:smirnov].full_name} from room #{rooms[:room_102].number}"
    rescue ActiveRecord::RecordInvalid => e
      puts "  WARNING: Eviction failed for #{residents[:smirnov].full_name}: #{e.message}"
    end
  end

  # Редактирование размещения Петровой — выполняет администратор
  Current.session = users[:dormitory_admin].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  acc_petrova = accommodations[:acc_petrova_201]
  if acc_petrova&.active?
    acc_petrova.do_update!(comment: "Заселение по приказу №123, обновлено администратором")
    puts "  Updated accommodation for #{residents[:petrova].full_name}"
  end

  # Редактирование проживающего — выполняет комендант
  Current.session = users[:dormitory_commandant].sessions.create!(ip_address: "127.0.0.1", user_agent: "seed")

  residents[:kozlova].do_update!(phone: "+79004567899", email: "kozlova@newmail.univer.local")
  puts "  Updated resident #{residents[:kozlova].full_name}"

  puts "Completed accommodations: #{Dormitory::Accommodation.where(status: :completed).count}"

  puts "\n=== Seed complete ==="
  puts "Login credentials (password: 'password'):"
  users.each { |key, u| puts "  #{key}: #{u.email_address}" }
end
