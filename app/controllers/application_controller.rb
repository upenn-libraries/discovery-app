class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller 
  include Blacklight::Controller
  layout 'blacklight'

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :check_hard_session_expiration

  def has_shib_session?
    session[:alma_sso_user].present? || request.headers['HTTP_REMOTE_USER'].present?
  end

  def shib_session_valid?
    session[:alma_sso_user] != request.headers['HTTP_REMOTE_USER']
  end

  def check_hard_session_expiration
    if (session[:hard_expiration] && session[:hard_expiration] < Time.now.to_i) ||
      (has_shib_session? && !shib_session_valid?)
      redirect_to '/', alert: 'Your session has expired, please log in again'
    end
  end

  def headers_debug
    content = '<html><body>'
    keys = request.headers.map { |header| header[0] }
    keys.sort.each do |key|
      content += "#{key} = #{request.headers[key]}<br/>"
    end
    content += '</body></html>'

    respond_to do |format|
      format.html {
        render html: content.html_safe
      }
    end
  end

  def session_debug
    content = '<html><body>'
    session.keys.sort.each do |key|
      content += "#{key} = #{session[key]}<br/>"
    end
    content += '</body></html>'

    respond_to do |format|
      format.html {
        render html: content.html_safe
      }
    end
  end

end
