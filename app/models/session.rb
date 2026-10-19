class Session < ApplicationRecord
  belongs_to :user

  validates :active_role, inclusion: { in: UserRole::NAMES }, allow_nil: true
end
