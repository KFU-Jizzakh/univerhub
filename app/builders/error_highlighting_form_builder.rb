# PURPOSE: Form builder that highlights fields with validation errors: adds the Bootstrap is-invalid class to the control and renders the error message below it
# SPECIFICATION: SPEC-DORM-12
class ErrorHighlightingFormBuilder < ActionView::Helpers::FormBuilder
  HIGHLIGHTED_FIELD_HELPERS = (field_helpers - %i[label checkbox check_box radio_button fields_for fields hidden_field]).freeze

  HIGHLIGHTED_FIELD_HELPERS.each do |helper|
    define_method(helper) do |method, options = {}, *args|
      options = error_aware_options(method, options)
      with_field_error(method) { super(method, options, *args) }
    end
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    html_options = error_aware_options(method, html_options)
    with_field_error(method) { super(method, choices, options, html_options, &block) }
  end

  private

  def error_aware_options(method, options)
    return options unless object.errors.include?(method)

    options.merge(class: [ options[:class], "is-invalid" ].compact_blank.join(" "))
  end

  def with_field_error(method)
    field = yield
    messages = object.errors.full_messages_for(method)
    return field if messages.none?

    unwrap_field_with_errors(field) + @template.tag.div(messages.to_sentence, class: "invalid-feedback")
  end

  def unwrap_field_with_errors(html)
    return html unless html.is_a?(String)

    html.delete_prefix('<div class="field_with_errors">').delete_suffix("</div>").html_safe
  end
end
