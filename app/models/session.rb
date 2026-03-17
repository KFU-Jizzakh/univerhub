class Session < ApplicationRecord
  # PURPOSE: User session for cookie-based authentication, stores ip_address and user_agent
  # SPECIFICATION: SPEC-CORE-01
  belongs_to :user
end
