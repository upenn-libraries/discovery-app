# frozen_string_literal: true

module Illiad
  # Represent an Illiad request
  class Request
    attr_accessor :recipient_username

    # @param [String] user_id
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [ActionController::Parameters] params
    def initialize(user_id, item, params)
      @username = user_id
      @recipient_username = params[:deliver_to] || user_id
      # TODO:
    end

    # for POSTing to API
    # @return [Hash]
    def to_h
      # TODO:
    end
  end
end
