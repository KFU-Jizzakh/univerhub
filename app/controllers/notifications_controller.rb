class NotificationsController < ApplicationController
  def index
    authorize Notification
    @pagy, @notifications = pagy(:offset, Current.user.notifications.recent.includes(:notifiable))
  end

  def mark_as_read
    @notification = Current.user.notifications.find(params[:id])
    authorize @notification
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@notification) }
      format.html { redirect_to notifications_path }
    end
  end

  def mark_all_as_read
    authorize Notification
    Current.user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: t("notifications.all_read")
  end
end
