# frozen_string_literal: true

class IllController < ApplicationController
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
    render text: 'Show ILL request info'
  end

  # list requests, etc.
  def index
    render text: 'Open ILL requests'
  end

  # cancel/remove request
  def destroy

  end
end
