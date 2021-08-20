# frozen_string_literal: true

module TurboAlmaApi
  # Represent a Franklin Request submission destined for Alma
  class Request

    attr_accessor :mms_id, :holding_id, :item_pid, :item
    attr_accessor :pickup_location, :pickup_location_human, :comments

    # @param [Hash] user
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [Hash] params
    def initialize(user, item = nil, params = {})
      @user = user
      @item = item
      @mms_id = params[:mms_id]
      @holding_id = params[:holding_id]
      @item_pid = params[:item_pid]
      @comments = params[:comments]
      @pickup_location = params[:pickup_location] || 'VanPeltLib'
      @pickup_location_human = pickup_location_human
    end

    # @return [String]
    def user_id
      @user[:id]
    end

    # @return [String]
    def email
      @user[:email]
    end

    def pickup_location_human
      location_info = TurboAlmaApi::Bib::PennItem::PICKUP_LOCATIONS.find { |loc_arr| loc_arr[1] == @pickup_location }
      location_info&.first
    end
  end
end
