class ActiveRolesController < ApplicationController
  def update
    role_name = params[:role_name].to_s
    authorize role_name, policy_class: ActiveRolePolicy

    Current.session.update!(active_role: role_name)
    Current.session.user.active_role_context = role_name
    redirect_to root_path, notice: t("active_roles.switched", role: t("roles.#{role_name}", default: role_name))
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn(
      "Authorization failed: #{Current.user&.id || 'guest'} tried to switch to unassigned role #{role_name.inspect}"
    )
    redirect_to root_path, alert: t("active_roles.not_assigned")
  end
end
