class UserProfile < ApplicationRecord
  # PURPOSE: User profile with name fields and avatar upload, belongs to user
  # SPECIFICATION: SPEC-CORE-03
  include Trackable

  belongs_to :user

  has_one_attached :avatar

  attr_accessor :remove_avatar

  ACCEPTED_AVATAR_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_AVATAR_SIZE = 5.megabytes

  validate :avatar_format_and_size
  before_save :purge_avatar_if_marked_for_removal

  def full_name
    [ last_name, first_name, middle_name ].compact_blank.join(" ").presence
  end

  def do_create!
    track_event("user_profile.created") { save! }
  end

  def do_update!(attrs)
    track_event("user_profile.updated") { update!(attrs) }
  end

  private

  def avatar_format_and_size
    return unless avatar.attached?

    unless avatar.content_type.in?(ACCEPTED_AVATAR_TYPES)
      errors.add(:avatar, :invalid_format)
    end

    if avatar.byte_size > MAX_AVATAR_SIZE
      errors.add(:avatar, :too_large, max_size: "#{MAX_AVATAR_SIZE / 1.megabyte} МБ")
    end
  end

  def purge_avatar_if_marked_for_removal
    if remove_avatar == "1" && avatar.attached?
      avatar.purge
    end
  end
end
