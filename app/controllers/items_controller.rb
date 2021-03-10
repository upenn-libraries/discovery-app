# frozen_string_literal: true

# Return Alma Items as JSON, as quickly as possible
class ItemsController < ApplicationController

  def one
    @item = client.item_for mms_id: params[:mms_id],
                            holding_id: params[:holding_id],
                            item_pid: params[:item_pid]
    render json: @item
  end

  def all
    @items = client.all_items_for params[:mms_id].to_s

    render json: @items
  end

  private

  def client
    TurboAlmaApi::Client
  end
end
