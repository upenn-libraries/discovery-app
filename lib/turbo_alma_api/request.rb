# frozen_string_literal: true

module TurboAlmaApi
  # Represent a Franklin Request submission destined for Alma
  class Request

    attr_accessor :mms_id, :holding_id, :item_pid
    attr_accessor :pickup_location, :comments
    attr_accessor :item, :user_id

    # @param [String] user_id
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [ActionController::Parameters] params
    def initialize(user_id, item = nil, params = {})
      @user_id = user_id
      @item = item
      @mms_id = params[:mms_id]
      @holding_id = params[:holding_id]
      @item_pid = params[:item_pid]
      @comments = params[:comments]
      @pickup_location = params[:pickup_location]
    end

    def target_system
      :alma
    end
  end
end
