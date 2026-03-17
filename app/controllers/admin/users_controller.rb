module Admin
  class UsersController < ApplicationController
    MODULE_ROLES = {
      "reporting.admin" => %w[reporting.manager reporting.reporter reporting.reviewer reporting.visitor reporting.admin],
      "dormitory.admin" => %w[dormitory.admin dormitory.commandant]
    }.freeze

    PROTECTED_ROLES = %w[admin dormitory.admin].freeze

    before_action :set_user, only: [ :show, :edit, :update, :activate, :deactivate, :destroy, :reset_password ]

    def index
      authorize [ :admin, User ]
      @pagy, @users = pagy(:offset, scoped_users.kept.includes(:roles, :profile).order(:email_address))
    end

    def show
      authorize [ :admin, @user ]
    end

    def new
      authorize [ :admin, User ]
      @user = User.new
      @user.build_profile
      @roles = scoped_roles
      @buildings = load_buildings
    end

    def create
      authorize [ :admin, User ]
      @user = User.new(user_create_params)

      role_ids = submitted_role_ids

      unless all_role_ids_exist?(role_ids)
        @user.errors.add(:role_ids, t("admin.users.invalid_role_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :new, status: :unprocessable_entity
        return
      end

      unless roles_within_scope?(role_ids)
        @user.errors.add(:role_ids, t("admin.users.invalid_role_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :new, status: :unprocessable_entity
        return
      end

      building_ids = submitted_building_ids

      unless all_building_ids_exist?(building_ids)
        @user.errors.add(:building_ids, t("admin.users.invalid_building_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        @user.save!
        if profile_params.values.any?(&:present?)
          @user.build_profile(profile_params)
          @user.profile.do_create!
        end
        @user.role_ids = role_ids
        assign_buildings!(@user, building_ids, role_ids)
      end

      redirect_to admin_user_path(@user), notice: t("admin.users.created")
    rescue ActiveRecord::RecordInvalid
      @roles = scoped_roles
      @buildings = load_buildings
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize [ :admin, @user ]
      @roles = scoped_roles
      @buildings = load_buildings
    end

    def update
      authorize [ :admin, @user ]

      role_ids = submitted_role_ids

      if self_demotion?(role_ids)
        @user.errors.add(:base, t("admin.users.cannot_remove_own_admin"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :edit, status: :unprocessable_entity
        return
      end

      unless all_role_ids_exist?(role_ids)
        @user.errors.add(:role_ids, t("admin.users.invalid_role_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :edit, status: :unprocessable_entity
        return
      end

      unless roles_within_scope?(role_ids)
        @user.errors.add(:role_ids, t("admin.users.invalid_role_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :edit, status: :unprocessable_entity
        return
      end

      building_ids = submitted_building_ids

      unless all_building_ids_exist?(building_ids)
        @user.errors.add(:building_ids, t("admin.users.invalid_building_ids"))
        @roles = scoped_roles
        @buildings = load_buildings
        render :edit, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        @user.update!(user_update_params)
        persist_profile!
        @user.role_ids = role_ids
        reassign_buildings!(@user, building_ids, role_ids)
      end

      redirect_to admin_user_path(@user), notice: t("admin.users.updated")
    rescue ActiveRecord::RecordInvalid
      @roles = scoped_roles
      @buildings = load_buildings
      render :edit, status: :unprocessable_entity
    end

    def activate
      authorize [ :admin, @user ]

      if @user == Current.user
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_activate_self")
        return
      end

      if scoped_module_admin_role && !user_in_module_scope?(@user)
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_manage_non_module_user")
        return
      end

      @user.activate!
      redirect_to admin_user_path(@user), notice: t("admin.users.activated")
    end

    def deactivate
      authorize [ :admin, @user ]

      if @user == Current.user
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_deactivate_self")
        return
      end

      if last_active_in_protected_role?(@user)
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_deactivate_last_admin")
        return
      end

      if scoped_module_admin_role && !user_in_module_scope?(@user)
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_manage_non_module_user")
        return
      end

      @user.deactivate!
      redirect_to admin_user_path(@user), notice: t("admin.users.deactivated")
    end

    def destroy
      authorize [ :admin, @user ]

      if @user == Current.user
        redirect_to admin_users_path, alert: t("admin.users.cannot_delete_self")
        return
      end

      if last_active_in_protected_role?(@user)
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_delete_last_admin")
        return
      end

      @user.discard!
      redirect_to admin_users_path, notice: t("admin.users.deleted")
    end

    def reset_password
      authorize [ :admin, @user ]

      temp_password = SecureRandom.hex(6)
      @user.update!(password: temp_password, password_confirmation: temp_password)
      @user.sessions.destroy_all

      redirect_to admin_user_path(@user), notice: t("admin.users.password_reset", password: temp_password)
    end

    private

    def set_user
      @user = User.with_discarded.find(params[:id])
    end

    def user_create_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end

    def user_update_params
      attrs = params.require(:user).permit(:email_address, :password, :password_confirmation).to_h
      attrs.delete("password") if attrs["password"].blank?
      attrs.delete("password_confirmation") if attrs["password_confirmation"].blank?
      attrs
    end

    def profile_params
      params.require(:user).permit(:first_name, :middle_name, :last_name, :avatar, :remove_avatar).to_h.slice("first_name", "middle_name", "last_name", "avatar", "remove_avatar")
    end

    def submitted_role_ids
      params.require(:user).permit(role_ids: []).fetch(:role_ids, [])
            .reject(&:blank?).map(&:to_i)
    end

    def submitted_building_ids
      params.require(:user).permit(building_ids: []).fetch(:building_ids, [])
            .reject(&:blank?).map(&:to_i)
    end

    def self_demotion?(role_ids)
      return false unless @user == Current.user
      admin_id = Role.find_by(name: "admin")&.id
      admin_id.present? && !role_ids.include?(admin_id)
    end

    def all_role_ids_exist?(role_ids)
      return true if role_ids.empty?
      return false if role_ids.length != role_ids.uniq.length
      Role.where(id: role_ids).count == role_ids.length
    end

    def all_building_ids_exist?(building_ids)
      return true if building_ids.empty?
      return false if building_ids.length != building_ids.uniq.length
      Dormitory::Building.kept.where(id: building_ids).count == building_ids.length
    end

    def persist_profile!
      attrs = profile_params.except("remove_avatar")
      remove_avatar = profile_params["remove_avatar"]
      attrs = attrs.compact_blank if @user.profile
      return if attrs.values.all?(&:blank?) && @user.profile.blank? && remove_avatar.blank?

      if @user.profile
        @user.profile.remove_avatar = remove_avatar if remove_avatar == "1"
        @user.profile.do_update!(attrs) if attrs.present?
      else
        @user.build_profile(attrs)
        @user.profile.do_create!
      end
    end

    def last_active_in_protected_role?(target)
      PROTECTED_ROLES.any? { |role_name| User.last_active_with_role?(target, role_name) }
    end

    def scoped_module_admin_role
      MODULE_ROLES.keys.find { |admin_role| Current.user.has_role?(admin_role) }
    end

    def scoped_roles
      admin_role = scoped_module_admin_role
      admin_role ? Role.where(name: MODULE_ROLES[admin_role]) : Role.all
    end

    def scoped_users
      admin_role = scoped_module_admin_role
      if admin_role
        User.joins(:roles).where(roles: { name: MODULE_ROLES[admin_role] }).distinct
      else
        User.with_discarded
      end
    end

    def roles_within_scope?(role_ids)
      admin_role = scoped_module_admin_role
      return true unless admin_role
      Role.where(id: role_ids).pluck(:name).all? { |n| MODULE_ROLES[admin_role].include?(n) }
    end

    def user_in_module_scope?(user_record)
      admin_role = scoped_module_admin_role
      return false unless admin_role
      return false if user_record.roles.empty?
      module_roles = MODULE_ROLES[admin_role]
      user_record.roles.pluck(:name).all? { |n| module_roles.include?(n) }
    end

    def load_buildings
      return [] unless commandant_role_in_scope?

      Dormitory::Building.kept.ordered
    end

    def assign_buildings!(user, building_ids, role_ids)
      return unless commandant_role_in_scope?
      return unless commandant_role_assigned?(role_ids)

      building_ids.each do |bid|
        Dormitory::CommandantBuilding.new(user: user, building_id: bid).do_create!
      end
    end

    def reassign_buildings!(user, new_building_ids, role_ids)
      return unless commandant_role_in_scope?
      return unless commandant_role_assigned?(role_ids)

      old_ids = user.commandant_buildings.active.pluck(:building_id)
      to_deactivate = old_ids - new_building_ids
      to_create = new_building_ids - old_ids

      Dormitory::CommandantBuilding.active
        .where(user: user, building_id: to_deactivate)
        .find_each(&:do_deactivate!)

      to_create.each do |bid|
        Dormitory::CommandantBuilding.new(user: user, building_id: bid).do_create!
      end
    end

    def commandant_role_in_scope?
      commandant_role = Role.find_by(name: "dormitory.commandant")
      return false unless commandant_role

      scoped_roles.exists?(commandant_role.id)
    end

    def commandant_role_assigned?(role_ids)
      commandant_role = Role.find_by(name: "dormitory.commandant")
      commandant_role && role_ids.include?(commandant_role.id)
    end
  end
end
