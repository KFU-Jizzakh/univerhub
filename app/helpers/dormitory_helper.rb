module DormitoryHelper
  CREATED_ACTION = "dormitory.resident.created"
  UPDATED_ACTION = "dormitory.resident.updated"

  def created_by_info(record)
    actor = actor_for_action(record, created_action_for(record))
    return "—" unless actor

    event = event_for_action(record, created_action_for(record))
    "#{user_display(actor)}, #{format_datetime(event&.created_at)}"
  end

  def last_modified_by(record)
    actor = actor_for_action(record, updated_action_for(record))
    return "—" unless actor

    event = event_for_action(record, updated_action_for(record))
    "#{user_display(actor)}, #{format_datetime(event&.created_at)}"
  end

  def who_settled(accommodation)
    actor_from_grouped(accommodation, "dormitory.accommodation.created")
  end

  def who_evicted(accommodation)
    actor_from_grouped(accommodation, "dormitory.accommodation.evicted")
  end

  def render_audit_trail(events)
    return unless events&.any?

    rows = events.map do |event|
      content_tag(:tr) do
        content_tag(:td, t("activity.actions.#{event.action}", default: event.action.humanize)) +
          content_tag(:td, event.actor ? user_display(event.actor) : "—") +
          content_tag(:td, format_datetime(event.created_at))
      end
    end.join.html_safe

    content_tag(:div, class: "audit-trail mt-4") do
      content_tag(:h5, t("views.shared.labels.history"), class: "mb-3") +
        content_tag(:div, class: "table-responsive") do
          content_tag(:table, class: "table table-sm table-hover align-middle") do
            content_tag(:thead, class: "table-light") do
              content_tag(:tr) do
                content_tag(:th, t("views.dormitory.audit.action")) +
                  content_tag(:th, t("views.dormitory.audit.actor")) +
                  content_tag(:th, t("views.dormitory.audit.datetime"))
              end
            end +
              content_tag(:tbody, rows)
          end
        end
    end
  end

  def resident_gender_options
    Dormitory::Resident.genders.map { |k, _v| [ t("views.dormitory.residents.gender_#{k}"), k ] }
  end

  private

  def actor_for_action(record, action)
    event = event_for_action(record, action)
    event&.actor
  end

  def event_for_action(record, action)
    OutboxEvent.where(record: record, action: action).order(created_at: :desc).first
  end

  def actor_from_grouped(accommodation, action)
    grouped = instance_variable_get(:@acc_events_by)
    return nil unless grouped
    events = grouped[[ accommodation.id, action ]]
    events&.last&.actor
  end

  def created_action_for(record)
    case record
    when Dormitory::Resident then "dormitory.resident.created"
    when Dormitory::Accommodation then "dormitory.accommodation.created"
    when Dormitory::Room then "dormitory.room.created"
    when Dormitory::Building then "dormitory.building.created"
    when Dormitory::AcademicYear then "dormitory.academic_year.created"
    else "created"
    end
  end

  def updated_action_for(record)
    case record
    when Dormitory::Resident then "dormitory.resident.updated"
    when Dormitory::Accommodation then "dormitory.accommodation.updated"
    when Dormitory::Room then "dormitory.room.updated"
    when Dormitory::Building then "dormitory.building.updated"
    when Dormitory::AcademicYear then "dormitory.academic_year.updated"
    else "updated"
    end
  end
end
