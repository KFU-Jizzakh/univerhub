module Dormitory
  class ReceiptsController < ApplicationController
    # PURPOSE: CRUD for payment receipts nested under an accommodation
    # SPECIFICATION: SPEC-DORM-09

    before_action :set_accommodation
    before_action :set_receipt, only: [ :edit, :update, :destroy ]

    def new
      @receipt = @accommodation.receipts.build(paid_at: Date.current, amount: params[:amount])
      authorize @receipt
      check_accommodation_active! or return
    end

    def create
      @receipt = @accommodation.receipts.build(receipt_params)
      authorize @receipt
      check_accommodation_active! or return
      @receipt.do_create!
      redirect_to dormitory_accommodation_path(@accommodation), notice: t("dormitory.receipts.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @receipt
    end

    def update
      authorize @receipt
      check_accommodation_active! or return
      @receipt.do_update!(receipt_params)
      redirect_to dormitory_accommodation_path(@accommodation), notice: t("dormitory.receipts.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @receipt
      check_accommodation_active! or return
      @receipt.do_discard!
      redirect_to dormitory_accommodation_path(@accommodation), notice: t("dormitory.receipts.destroyed")
    end

    private

    def set_accommodation
      @accommodation = Dormitory::Accommodation.kept.find(params[:accommodation_id])
    end

    def set_receipt
      @receipt = @accommodation.receipts.kept.find(params[:id])
    end

    def receipt_params
      params.require(:dormitory_receipt).permit(:amount, :paid_at, :comment, :attachment)
    end

    def check_accommodation_active!
      return true if @accommodation.active?

      redirect_to dormitory_accommodation_path(@accommodation), alert: t("dormitory.accommodations.not_active")
      false
    end
  end
end
