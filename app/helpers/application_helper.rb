module ApplicationHelper
  STATUS_LABELS = {
    "draft" => "Черновик",
    "new" => "Новый",
    "in_progress" => "В работе",
    "in_review" => "На проверке",
    "accepted" => "Принят",
    "rejected" => "Отклонён",
    "reopened" => "Переоткрыт",
    "published" => "Опубликован",
    "archived" => "Архив",
    "free" => "Свободна",
    "partially_occupied" => "Занята частично",
    "fully_occupied" => "Занята полностью",
    "overcrowded" => "Переполнена",
    "not_settled" => "Не заселён",
    "settled" => "Заселён",
    "temporarily_absent" => "Временно отсутствует",
    "evicted" => "Выселен",
    "active" => "Активно",
    "completed" => "Завершено",
    "partial" => "Частично завершено",
    "cancelled" => "Отменено",
    "pending" => "Ожидает",
    "closed" => "Закрыт"
  }.freeze

  def current_user
    Current.user
  end

  def has_role?(name)
    current_user&.has_role?(name)
  end

  def status_badge(status)
    label = STATUS_LABELS[status.to_s] || status.to_s.humanize
    tag.span(label, class: "status-badge status-badge--#{status}")
  end

  def deadline_badge(report)
    return unless report.deadline.present? && !report.accepted?

    if report.overdue?
      tag.span(t("deadline.overdue"), class: "status-badge status-badge--rejected")
    elsif report.deadline_soon?
      tag.span(t("deadline.soon"), class: "status-badge status-badge--in_progress")
    end
  end

  def sidebar_link(label, path, exact: false, icon: nil)
    active = if exact || path == "/"
               request.path == path
    else
               request.path == path || request.path.match?(/\A#{Regexp.escape(path)}\/\d/)
    end
    icon_html = tag.i(class: "bi #{icon}") if icon
    link_to(path, class: ("active" if active)) { safe_join([ icon_html, label ].compact, " ") }
  end

  def format_datetime(dt)
    return "—" unless dt
    l(dt, format: :short)
  end

  def user_display(user)
    return "—" unless user
    user.profile&.full_name || user.email_address.split("@").first.capitalize
  end

  def user_avatar(user, size: :index)
    return initials_avatar(40) unless user

    avatar_size = case size
    when :navbar then 32
    when :index then 40
    when :show then 80
    when :comment then 24
    else 40
    end

    profile = user.profile
    if profile&.avatar&.attached?
      variant = profile.avatar.variant(resize_to_fill: [ avatar_size, avatar_size ])
      tag.img(
        src: url_for(variant),
        alt: user_display(user),
        class: "rounded-circle",
        style: "width: #{avatar_size}px; height: #{avatar_size}px; object-fit: cover;"
      )
    else
      initials_avatar(avatar_size, user)
    end
  end

  def initials_avatar(size, user = nil)
    initials = if user&.profile
      [ user.profile.last_name, user.profile.first_name ].compact_blank.map { |n| n[0] }.join.upcase
    elsif user
      user.email_address.split("@").first[0..1].upcase
    else
      "?"
    end
    initials = "?" if initials.blank?

    tag.span(
      initials,
      class: "d-inline-flex align-items-center justify-content-center rounded-circle bg-light text-secondary fw-bold",
      style: "width: #{size}px; height: #{size}px; font-size: #{(size * 0.4).round}px;"
    )
  end

  def breadcrumbs(&block)
    content_for(:breadcrumbs, &block)
  end

  def breadcrumb(label, path = nil)
    if path
      tag.li { link_to label, path }
    else
      tag.li(label, class: "current")
    end
  end

  def pagy_nav_html(pagy)
    return "" if pagy.pages <= 1
    pagy.series_nav(:bootstrap).html_safe
  end

  def file_icon_class(attachment)
    case attachment.content_type.to_s
    when "application/pdf" then "bi-filetype-pdf"
    when "image/jpeg" then "bi-filetype-jpg"
    when "image/png" then "bi-filetype-png"
    else "bi-file-earmark"
    end
  end

  def activity_icon(action)
    icon = case action
    when "reporting.report.published" then "clipboard-check"
    when "reporting.report.taken_in_progress" then "lightning"
    when "reporting.report.submitted" then "send"
    when "reporting.report.accepted" then "check-circle"
    when "reporting.report.rejected" then "x-circle"
    when "reporting.report.reopened" then "arrow-repeat"
    when "reporting.report_template.published" then "file-earmark"
    when "reporting.report_template.archived" then "archive"
    when "reporting.report_comment.created", "reporting.report_comment.updated", "reporting.report_comment.destroyed" then "chat"
    when "reporting.report_item.updated", "reporting.report_item.graded" then "pencil"
    when "dormitory.building.created", "dormitory.building.updated", "dormitory.building.discarded" then "building"
    when "dormitory.room.created", "dormitory.room.updated", "dormitory.room.discarded" then "door-open"
    when "dormitory.resident.created", "dormitory.resident.updated", "dormitory.resident.discarded" then "person"
    when "dormitory.accommodation.created", "dormitory.accommodation.updated", "dormitory.accommodation.transferred", "dormitory.accommodation.evicted" then "house-door"
    when "dormitory.commandant_building.created", "dormitory.commandant_building.updated", "dormitory.commandant_building.deactivated", "dormitory.commandant_building.destroyed" then "key"
    when "dormitory.academic_year.created", "dormitory.academic_year.updated", "dormitory.academic_year.activated", "dormitory.academic_year.closed" then "calendar3"
    when "user_profile.created", "user_profile.updated" then "person-badge"
    when "role.created", "role.updated", "role.destroyed" then "key"
    when "user_role.created", "user_role.updated", "user_role.destroyed" then "shield-lock"
    else "circle"
    end
    tag.i(class: "bi bi-#{icon}")
  end

  def attachment_disposition(attachment)
    content_type = attachment.content_type.to_s
    if content_type.start_with?("image/") || content_type == "application/pdf"
      "inline"
    else
      "attachment"
    end
  end
end
