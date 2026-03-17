module Trackable
  # PURPOSE: Concern that wraps operations in a transaction and creates an OutboxEvent with actor, action, record, and payload
  # SPECIFICATION: SPEC-CORE-04
  extend ActiveSupport::Concern

  private

  def track_event(action, payload = {})
    ActiveRecord::Base.transaction do
      result = yield if block_given?
      raise ActiveRecord::Rollback if result == false

      OutboxEvent.create!(
        actor: Current.user,
        action: action,
        record: self,
        payload: payload.respond_to?(:call) ? payload.call : payload
      )
      result
    end
  end
end
