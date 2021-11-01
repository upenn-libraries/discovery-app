# frozen_string_literal: true

class IllController < ApplicationController
  before_action :user_check

  # show form to create a new request
  def new
    @request = RequestItem.new
    @request.populate_from params
    # render the proper form partial? book vs article? avoid logic in view
  end

  # create request
  def create
    @ill_request = Illiad::Request.new(
      { id: session[:id], email: session[:email] },
      @item, # TODO: Illiad::Request expects a PennItem....which we can only build from an MMS ID
      {} # params - expects :comments, :delivery (office, mail, electronic)
    )
  end

  # show request info, confirmation?
  def show
    @request = Illiad::ApiClient.new.get_transaction params[:id]
  end

  # list requests, etc.
  def index
    @requests = Illiad::ApiClient.new.transactions session['id']
  end

  # cancel/remove request
  def destroy

  end

  private

  def user_check
    if session['id'].present? && session['user_group'] != 'Courtesy Borrower'
      return true
    end

    redirect_to root_url, alert: 'Sorry, you must be logged in as an approved Penn Libraries patron to use ILL services.'
  end
end
