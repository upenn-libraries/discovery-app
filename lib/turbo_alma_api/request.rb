# frozen_string_literal: true

module TurboAlmaApi
  # Represent a Franklin Request submission destined for Alma
  class Request

    attr_accessor :mms_id, :holding_id, :item_pid, :item
    attr_accessor :pickup_location, :comments

    # @param [Hash] user
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [ActionController::Parameters] params
    def initialize(user, item = nil, params = {})
      @user = user
      @item = item
      @mms_id = params[:mms_id]
      @holding_id = params[:holding_id]
      @item_pid = params[:item_pid]
      @comments = params[:comments]
      @pickup_location = params[:pickup_location] || 'VanPeltLib'
    end

    # @return [String]
    def user_id
      @user[:id]
    end

    # @return [String]
    def submitter_email
      @user[:email]
    end
  end
end
