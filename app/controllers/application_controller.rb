class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller 
  include Blacklight::Controller
  layout 'blacklight'

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # TODO: hack to spoof X-Forwarded-Proto header so that links are rendered as https
  before_action :set_x_forwarded_proto

  def set_x_forwarded_proto
    if Rails.env.production?
      request.headers['X-Forwarded-Proto'] = 'https'
    end
  end

end
