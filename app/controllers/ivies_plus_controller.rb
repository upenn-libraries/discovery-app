require 'requesting/relais'

class IviesPlusController < ApplicationController

  def index
    render :requests, locals: {:requests => open_requests}
  end

  def new_request
    # TODO:  Add check and handling for empty title
    title = SolrDocument.find(params['id']).fetch(:title, '')

    render :new_request, locals: {:title => title}
  end

  def place_request
    user_id = session['id'].presence
    title = params[:title]
    aid = Relais.authenticate(user_id)
    response = Relais.addRequest(aid, user_id, title)

    render :request_placed, locals: {:message => response["ConfirmMessage"] || response["Problem"]["Message"]}
  end

  def open_requests
    user_id = session['id'].presence
    aid = Relais.authenticate(user_id)
    Relais.getRequests(aid)['MyRequestRecords'] || []
  end

end
