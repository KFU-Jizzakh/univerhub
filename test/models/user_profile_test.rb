require "test_helper"

class UserProfileTest < ActiveSupport::TestCase
  setup do
    @user = users(:manager_user)
    Current.session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  test "full_name joins last, first and middle name" do
    profile = UserProfile.new(last_name: "Иванов", first_name: "Иван", middle_name: "Петрович")
    assert_equal "Иванов Иван Петрович", profile.full_name
  end

  test "full_name joins last and first name without middle" do
    profile = UserProfile.new(last_name: "Иванов", first_name: "Иван")
    assert_equal "Иванов Иван", profile.full_name
  end

  test "full_name returns only last name when others blank" do
    profile = UserProfile.new(last_name: "Иванов")
    assert_equal "Иванов", profile.full_name
  end

  test "full_name returns nil when all names blank" do
    assert_nil UserProfile.new.full_name
  end

  test "do_create! creates UserProfile and OutboxEvent" do
    profile = @user.build_profile(last_name: "Петров", first_name: "Пётр")

    assert_difference "UserProfile.count", 1 do
      assert_difference "OutboxEvent.count", 1 do
        profile.do_create!
      end
    end

    assert_equal "user_profile.created", OutboxEvent.last.action
    assert_equal profile, OutboxEvent.last.record
  end

  test "do_update! updates UserProfile and creates OutboxEvent" do
    profile = @user.profile || @user.create_profile!(last_name: "Старый")

    assert_difference "OutboxEvent.count", 1 do
      profile.do_update!(last_name: "Новый", first_name: "Имя")
    end

    assert_equal "Новый", profile.reload.last_name
    assert_equal "user_profile.updated", OutboxEvent.last.action
  end

  test "valid avatar with jpeg" do
    profile = @user.build_profile(last_name: "Тест")
    profile.avatar.attach(io: File.open(Rails.root.join("test/fixtures/files/avatar.jpg")), filename: "avatar.jpg", content_type: "image/jpeg")
    assert profile.valid?
  end

  test "valid avatar with png" do
    profile = @user.build_profile(last_name: "Тест")
    profile.avatar.attach(io: File.open(Rails.root.join("test/fixtures/files/avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert profile.valid?
  end

  test "valid avatar with webp" do
    profile = @user.build_profile(last_name: "Тест")
    profile.avatar.attach(io: File.open(Rails.root.join("test/fixtures/files/avatar.webp")), filename: "avatar.webp", content_type: "image/webp")
    assert profile.valid?
  end

  test "invalid avatar with pdf" do
    profile = @user.build_profile(last_name: "Тест")
    profile.avatar.attach(io: File.open(Rails.root.join("test/fixtures/files/test.pdf")), filename: "doc.pdf", content_type: "application/pdf")
    assert_not profile.valid?
    assert_predicate profile.errors[:avatar], :any?
  end

  test "avatar too large" do
    profile = @user.build_profile(last_name: "Тест")
    oversized_file = StringIO.new("x" * (6.megabytes))
    profile.avatar.attach(io: oversized_file, filename: "big.jpg", content_type: "image/jpeg")
    assert_not profile.valid?
    assert_includes profile.errors[:avatar], "размер файла превышает 5 МБ"
  end

  test "remove_avatar purges attachment" do
    profile = @user.build_profile(last_name: "Тест")
    profile.avatar.attach(io: File.open(Rails.root.join("test/fixtures/files/avatar.jpg")), filename: "avatar.jpg", content_type: "image/jpeg")
    profile.save!
    assert profile.avatar.attached?

    profile.remove_avatar = "1"
    profile.save!
    assert_not profile.reload.avatar.attached?
  end
end
