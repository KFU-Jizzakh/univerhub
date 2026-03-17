require "test_helper"

class ScenariosTest < ActionDispatch::IntegrationTest
  # ===== Health =====

  test "GET /up returns 200" do
    get "/up"
    assert_response :success
  end

  # ===== Без авторизации =====

  test "GET / redirects to login when not authenticated" do
    get "/"
    assert_redirected_to new_session_path
  end

  test "GET /reports redirects to login when not authenticated" do
    get reporting_reports_path
    assert_redirected_to new_session_path
  end

  test "GET /admin/users redirects to login when not authenticated" do
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "GET /report_templates redirects to login when not authenticated" do
    get reporting_report_templates_path
    assert_redirected_to new_session_path
  end

  test "GET /notifications redirects to login when not authenticated" do
    get notifications_path
    assert_redirected_to new_session_path
  end

  test "GET /activity_feed redirects to login when not authenticated" do
    get activity_feed_index_path
    assert_redirected_to new_session_path
  end

  # ===== Страница входа =====

  test "GET /session/new returns login form" do
    get new_session_path
    assert_response :success
    assert_select "input[name='email_address']"
    assert_select "input[name='password']"
  end

  # ===== Логин / логаут =====

  test "POST /session with valid credentials redirects to root" do
    user = users(:admin_user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    assert_redirected_to root_path
  end

  test "POST /session with invalid credentials redirects back" do
    user = users(:admin_user)
    post session_path, params: { email_address: user.email_address, password: "wrong" }
    assert_redirected_to new_session_path
  end

  test "DELETE /session logs out and redirects" do
    sign_in_as(users(:admin_user))
    delete session_path
    assert_redirected_to new_session_path
    get reporting_reports_path
    assert_redirected_to new_session_path
  end

  # ===== admin =====

  test "admin can access dashboard" do
    sign_in_as(users(:admin_user))
    get "/"
    assert_response :success
  end

  test "admin can access /admin/users" do
    sign_in_as(users(:admin_user))
    get admin_users_path
    assert_response :success
  end

  test "admin can access /reports" do
    sign_in_as(users(:admin_user))
    get reporting_reports_path
    assert_response :success
  end

  test "admin can access /activity_feed" do
    sign_in_as(users(:admin_user))
    get activity_feed_index_path
    assert_response :success
  end

  test "admin can access /reporters" do
    sign_in_as(users(:admin_user))
    get reporting_reporters_path
    assert_response :success
  end

  test "admin can access /notifications" do
    sign_in_as(users(:admin_user))
    get notifications_path
    assert_response :success
  end

  test "admin can access /report_templates" do
    sign_in_as(users(:admin_user))
    get reporting_report_templates_path
    assert_response :success
  end

  # ===== report_manager =====

  test "report_manager can access /report_templates" do
    sign_in_as(users(:manager_user))
    get reporting_report_templates_path
    assert_response :success
  end

  test "report_manager can access GET /reports" do
    sign_in_as(users(:manager_user))
    get reporting_reports_path
    assert_response :success
  end

  test "reports index ignores malformed deadline_from" do
    sign_in_as(users(:manager_user))
    get reporting_reports_path, params: { deadline_from: "not-a-date" }
    assert_response :success
  end

  test "reports index filters by valid deadline_from" do
    sign_in_as(users(:manager_user))
    get reporting_reports_path, params: { deadline_from: "2026-01-01" }
    assert_response :success
  end

  test "report_manager can create report_template" do
    sign_in_as(users(:manager_user))
    assert_difference "Reporting::ReportTemplate.count", 1 do
      post reporting_report_templates_path, params: { reporting_report_template: { name: "New Template via test" } }
    end
    assert_response :redirect
  end

  test "report_manager can access GET /reports/new" do
    sign_in_as(users(:manager_user))
    get new_reporting_report_path
    assert_response :success
  end

  test "report_manager cannot access /activity_feed" do
    sign_in_as(users(:manager_user))
    get activity_feed_index_path
    assert_redirected_to root_path
  end

  test "report_manager cannot access /admin/users" do
    sign_in_as(users(:manager_user))
    get admin_users_path
    assert_redirected_to root_path
  end

  # ===== reporter =====

  test "reporter can access /reports" do
    sign_in_as(users(:reporter_user))
    get reporting_reports_path
    assert_response :success
  end

  test "reporter can access /notifications" do
    sign_in_as(users(:reporter_user))
    get notifications_path
    assert_response :success
  end

  test "reporter cannot access /admin/users" do
    sign_in_as(users(:reporter_user))
    get admin_users_path
    assert_redirected_to root_path
  end

  test "reporter cannot access /activity_feed" do
    sign_in_as(users(:reporter_user))
    get activity_feed_index_path
    assert_redirected_to root_path
  end

  test "reporter cannot create report_template" do
    sign_in_as(users(:reporter_user))
    assert_no_difference "Reporting::ReportTemplate.count" do
      post reporting_report_templates_path, params: { reporting_report_template: { name: "Forbidden" } }
    end
    assert_redirected_to root_path
  end

  test "reporter can take in_progress their own new report" do
    sign_in_as(users(:reporter_user))
    patch take_in_progress_reporting_report_path(reporting_reports(:new_report))
    assert_redirected_to reporting_report_path(reporting_reports(:new_report))
    assert_equal "in_progress", reporting_reports(:new_report).reload.status
  end

  test "reporter can submit their in_progress report" do
    sign_in_as(users(:reporter_user))
    patch submit_reporting_report_path(reporting_reports(:in_progress_report))
    assert_redirected_to reporting_report_path(reporting_reports(:in_progress_report))
    assert_equal "in_review", reporting_reports(:in_progress_report).reload.status
  end

  # ===== report_reviewer =====

  test "reviewer can access /reports" do
    sign_in_as(users(:reviewer_user))
    get reporting_reports_path
    assert_response :success
  end

  test "reviewer can access /notifications" do
    sign_in_as(users(:reviewer_user))
    get notifications_path
    assert_response :success
  end

  test "reviewer cannot access /admin/users" do
    sign_in_as(users(:reviewer_user))
    get admin_users_path
    assert_redirected_to root_path
  end

  test "reviewer can accept an in_review report" do
    sign_in_as(users(:reviewer_user))
    patch accept_reporting_report_path(reporting_reports(:in_review_report))
    assert_redirected_to reporting_report_path(reporting_reports(:in_review_report))
    assert_equal "accepted", reporting_reports(:in_review_report).reload.status
  end

  # ===== supervisor =====

  test "supervisor can access /activity_feed" do
    sign_in_as(users(:supervisor_user))
    get activity_feed_index_path
    assert_response :success
  end

  test "supervisor can access /reporters" do
    sign_in_as(users(:supervisor_user))
    get reporting_reporters_path
    assert_response :success
  end

  test "supervisor cannot access /admin/users" do
    sign_in_as(users(:supervisor_user))
    get admin_users_path
    assert_redirected_to root_path
  end

  # ===== visitor =====

  test "visitor can access /reports" do
    sign_in_as(users(:visitor_user))
    get reporting_reports_path
    assert_response :success
  end

  test "visitor can access /reporters" do
    sign_in_as(users(:visitor_user))
    get reporting_reporters_path
    assert_response :success
  end

  test "visitor cannot access /activity_feed" do
    sign_in_as(users(:visitor_user))
    get activity_feed_index_path
    assert_redirected_to root_path
  end

  test "visitor cannot access /admin/users" do
    sign_in_as(users(:visitor_user))
    get admin_users_path
    assert_redirected_to root_path
  end

  test "visitor cannot create report comment" do
    sign_in_as(users(:visitor_user))
    assert_no_difference "Reporting::ReportComment.count" do
      post reporting_report_comments_path(reporting_reports(:in_review_report)), params: {
        reporting_report_comment: { body: "Попытка" }
      }
    end
    assert_redirected_to root_path
  end

  # ===== Уведомления =====

  test "mark_all_as_read marks all notifications read" do
    user = users(:reporter_user)
    Notification.create!(recipient: user, action: "reporting.report.assigned", notifiable: reporting_reports(:new_report))
    sign_in_as(user)
    patch mark_all_as_read_notifications_path
    assert_redirected_to notifications_path
    assert_equal 0, user.notifications.unread.count
  end

  # ===== admin: управление пользователями =====

  test "admin can create user" do
    sign_in_as(users(:admin_user))
    assert_difference "User.count", 1 do
      post admin_users_path, params: {
        user: { email_address: "newuser@test.local", password: "password", password_confirmation: "password" }
      }
    end
  end

  test "admin create with short password renders 422" do
    sign_in_as(users(:admin_user))
    assert_no_difference "User.count" do
      post admin_users_path, params: {
        user: { email_address: "short@test.local", password: "abc", password_confirmation: "abc" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin create with invalid email renders 422" do
    sign_in_as(users(:admin_user))
    assert_no_difference "User.count" do
      post admin_users_path, params: {
        user: { email_address: "not-an-email", password: "password", password_confirmation: "password" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin can view user" do
    sign_in_as(users(:admin_user))
    get admin_user_path(users(:reporter_user))
    assert_response :success
  end

  test "admin can update user email" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    patch admin_user_path(user), params: {
      user: { email_address: "changed@test.local", role_ids: [ roles(:reporting_reporter).id ] }
    }
    assert_redirected_to admin_user_path(user)
    assert_equal "changed@test.local", user.reload.email_address
  end

  test "admin update with blank password does not change digest" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    digest_before = user.password_digest
    patch admin_user_path(user), params: {
      user: { email_address: user.email_address, password: "", password_confirmation: "", role_ids: [ roles(:reporting_reporter).id ] }
    }
    assert_redirected_to admin_user_path(user)
    assert_equal digest_before, user.reload.password_digest
  end

  test "admin update with new password changes digest" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    digest_before = user.password_digest
    patch admin_user_path(user), params: {
      user: { email_address: user.email_address, password: "newpass1", password_confirmation: "newpass1", role_ids: [ roles(:reporting_reporter).id ] }
    }
    assert_redirected_to admin_user_path(user)
    assert_not_equal digest_before, user.reload.password_digest
  end

  test "admin update with mismatched password confirmation renders 422" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    patch admin_user_path(user), params: {
      user: { email_address: user.email_address, password: "abc", password_confirmation: "xyz", role_ids: [ roles(:reporting_reporter).id ] }
    }
    assert_response :unprocessable_entity
  end

  test "admin cannot remove their own admin role" do
    sign_in_as(users(:admin_user))
    patch admin_user_path(users(:admin_user)), params: {
      user: { email_address: users(:admin_user).email_address, role_ids: [ roles(:supervisor).id ] }
    }
    assert_response :unprocessable_entity
    assert_includes users(:admin_user).reload.roles.pluck(:name), "admin"
  end

  test "admin update with unknown role_id renders 422" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    original_role_ids = user.role_ids.sort
    patch admin_user_path(user), params: {
      user: { email_address: user.email_address, role_ids: [ 999_999 ] }
    }
    assert_response :unprocessable_entity
    assert_equal original_role_ids, user.reload.role_ids.sort
  end

  test "admin update creates profile when not present" do
    sign_in_as(users(:admin_user))
    user = users(:reporter_user)
    assert_nil user.profile
    patch admin_user_path(user), params: {
      user: { email_address: user.email_address, first_name: "Новое", last_name: "Имя", role_ids: [ roles(:reporting_reporter).id ] }
    }
    assert_redirected_to admin_user_path(user)
    assert_equal "Новое", user.reload.profile.first_name
  end

  # ===== Отчёты: создание и управление =====

  test "report_manager can create report" do
    sign_in_as(users(:manager_user))
    assert_difference "Reporting::Report.count", 1 do
      post reporting_reports_path, params: {
        reporting_report: {
          name: "Тест отчёт",
          reporter_id: users(:reporter_user).id,
          reviewer_id: users(:reviewer_user).id,
          deadline: 1.month.from_now
        }
      }
    end
    assert_response :redirect
  end

  test "reporter cannot create report" do
    sign_in_as(users(:reporter_user))
    assert_no_difference "Reporting::Report.count" do
      post reporting_reports_path, params: {
        reporting_report: { name: "Запрещено", reporter_id: users(:reporter_user).id }
      }
    end
    assert_redirected_to root_path
  end

  test "report_manager create with unknown template_id renders 422" do
    sign_in_as(users(:manager_user))
    assert_no_difference "Reporting::Report.count" do
      post reporting_reports_path, params: {
        reporting_report: { name: "Тест", report_template_id: 999_999 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "report_manager create with archived template_id renders 422" do
    sign_in_as(users(:manager_user))
    archived = Reporting::ReportTemplate.create!(name: "Архивный", status: :archived, creator: users(:manager_user))
    assert_no_difference "Reporting::Report.count" do
      post reporting_reports_path, params: {
        reporting_report: { name: "Тест", report_template_id: archived.id }
      }
    end
    assert_response :unprocessable_entity
  end

  test "report_manager can publish report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)
    report.update!(reporter: users(:reporter_user), reviewer: users(:reviewer_user), deadline: 1.month.from_now)
    report.report_items.create!(name: "Пункт")
    assert_difference "Notification.count", 1 do
      patch publish_reporting_report_path(report)
    end
    assert_redirected_to reporting_report_path(report)
    assert_equal "new", report.reload.status
  end

  test "report_manager can update their own draft report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)
    patch reporting_report_path(report), params: { reporting_report: { name: "Новое имя черновика" } }
    assert_redirected_to reporting_report_path(report)
    assert_equal "Новое имя черновика", report.reload.name
  end

  test "reporter cannot update report metadata on their in_progress report" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:in_progress_report)
    original_deadline = report.deadline
    original_reviewer_id = report.reviewer_id
    patch reporting_report_path(report), params: {
      reporting_report: { deadline: 1.year.from_now, reviewer_id: users(:admin_user).id }
    }
    assert_redirected_to root_path
    report.reload
    assert_equal original_deadline.to_i, report.deadline.to_i
    assert_equal original_reviewer_id, report.reviewer_id
  end

  test "report_manager cannot update a non-draft report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_progress_report)
    original_name = report.name
    patch reporting_report_path(report), params: { reporting_report: { name: "Должно быть запрещено" } }
    assert_redirected_to root_path
    assert_equal original_name, report.reload.name
  end

  test "reporter can reopen rejected report" do
    sign_in_as(users(:reporter_user))
    patch reopen_reporting_report_path(reporting_reports(:rejected_report))
    assert_redirected_to reporting_report_path(reporting_reports(:rejected_report))
    assert_equal "reopened", reporting_reports(:rejected_report).reload.status
  end

  test "reporter cannot take in_progress a non-new report" do
    sign_in_as(users(:reporter_user))
    patch take_in_progress_reporting_report_path(reporting_reports(:in_progress_report))
    assert_redirected_to root_path
    assert_equal "in_progress", reporting_reports(:in_progress_report).reload.status
  end

  test "reviewer cannot reject non-in_review report" do
    sign_in_as(users(:reviewer_user))
    patch reject_reporting_report_path(reporting_reports(:in_progress_report)),
      params: { rejection_reason: "Причина" }
    assert_redirected_to root_path
    assert_equal "in_progress", reporting_reports(:in_progress_report).reload.status
  end

  test "reporter cannot reopen non-rejected report" do
    sign_in_as(users(:reporter_user))
    patch reopen_reporting_report_path(reporting_reports(:in_progress_report))
    assert_redirected_to root_path
    assert_equal "in_progress", reporting_reports(:in_progress_report).reload.status
  end

  # ===== Оценка пунктов =====

  test "reviewer can grade a report item" do
    sign_in_as(users(:reviewer_user))
    item = reporting_report_items(:graded_item)
    patch grade_reporting_report_report_item_path(item.report, item),
      params: { reporting_report_item: { grade: 8, grade_comment: "Отлично" } }
    assert_redirected_to reporting_report_path(item.report)
    assert_equal 8, item.reload.grade
  end

  test "reviewer can access grade edit form" do
    sign_in_as(users(:reviewer_user))
    item = reporting_report_items(:graded_item)
    get edit_grade_reporting_report_report_item_path(item.report, item)
    assert_response :success
  end

  test "user without reporter role cannot update report items even if still assigned" do
    user = users(:reporter_user)
    report = reporting_reports(:in_progress_report)
    item = report.report_items.create!(name: "Пункт для редактирования")
    user.user_roles.destroy_all

    sign_in_as(user)
    get edit_reporting_report_report_item_path(report, item)
    assert_redirected_to root_path

    patch reporting_report_report_item_path(report, item), params: { report_item: { content: "hacked" } }
    assert_redirected_to root_path
    assert_nil item.reload.content
  end

  test "reporter cannot grade report items" do
    sign_in_as(users(:reporter_user))
    item = reporting_report_items(:graded_item)
    patch grade_reporting_report_report_item_path(item.report, item),
      params: { reporting_report_item: { grade: 8 } }
    assert_redirected_to root_path
    assert_not_equal 8, item.reload.grade
  end

  test "reviewer can reject in_review report with reason" do
    sign_in_as(users(:reviewer_user))
    patch reject_reporting_report_path(reporting_reports(:in_review_report)),
      params: { rejection_reason: "Недостаточно данных" }
    assert_redirected_to reporting_report_path(reporting_reports(:in_review_report))
    report = reporting_reports(:in_review_report).reload
    assert_equal "rejected", report.status
    assert_equal "Недостаточно данных", report.rejection_reason
  end

  test "reviewer cannot accept report when items not graded" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)
    report.report_items.create!(name: "Без оценки")
    patch accept_reporting_report_path(report)
    assert_redirected_to root_path
    assert_equal "in_review", report.reload.status
  end

  # ===== Исполнители =====

  test "visitor can view reporter profile" do
    sign_in_as(users(:visitor_user))
    get reporting_reporter_path(users(:reporter_user))
    assert_response :success
  end

  test "visitor cannot view non-reporter profile via reporters path" do
    sign_in_as(users(:visitor_user))
    get reporting_reporter_path(users(:admin_user))
    assert_redirected_to reporting_reporters_path
  end

  test "reporter cannot access reporters list" do
    sign_in_as(users(:reporter_user))
    get reporting_reporters_path
    assert_redirected_to root_path
  end

  # ===== Просмотр отчётов: visitor и draft =====

  test "visitor cannot view draft report" do
    sign_in_as(users(:visitor_user))
    get reporting_report_path(reporting_reports(:draft_report))
    assert_redirected_to root_path
  end

  test "visitor can view published report" do
    sign_in_as(users(:visitor_user))
    get reporting_report_path(reporting_reports(:new_report))
    assert_response :success
  end

  test "supervisor can view draft report" do
    sign_in_as(users(:supervisor_user))
    get reporting_report_path(reporting_reports(:draft_report))
    assert_response :success
  end

  # ===== Просмотр шаблонов =====

  test "admin can view draft template" do
    sign_in_as(users(:admin_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_response :success
  end

  test "report_manager can view draft template" do
    sign_in_as(users(:manager_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_response :success
  end

  test "reporter cannot view draft template" do
    sign_in_as(users(:reporter_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_redirected_to root_path
  end

  test "reviewer cannot view draft template" do
    sign_in_as(users(:reviewer_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_redirected_to root_path
  end

  test "supervisor cannot view draft template" do
    sign_in_as(users(:supervisor_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_redirected_to root_path
  end

  test "visitor cannot view draft template" do
    sign_in_as(users(:visitor_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_redirected_to root_path
  end

  test "visitor can view published template" do
    sign_in_as(users(:visitor_user))
    get reporting_report_template_path(reporting_report_templates(:published_template))
    assert_response :success
  end

  test "reporter can view published template" do
    sign_in_as(users(:reporter_user))
    get reporting_report_template_path(reporting_report_templates(:published_template))
    assert_response :success
  end

  test "admin sees draft templates in index" do
    sign_in_as(users(:admin_user))
    get reporting_report_templates_path
    assert_response :success
    assert_match reporting_report_templates(:draft_template).name, response.body
  end

  test "visitor does not see draft templates in index" do
    sign_in_as(users(:visitor_user))
    get reporting_report_templates_path
    assert_response :success
    assert_no_match(/#{Regexp.escape(reporting_report_templates(:draft_template).name)}/, response.body)
    assert_match reporting_report_templates(:published_template).name, response.body
  end
end
