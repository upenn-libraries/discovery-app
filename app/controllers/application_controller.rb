class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller 
  include Blacklight::Controller
  layout 'blacklight'

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

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

  def known_issues
    render :template => "/known_issues"
  end

  def databases_empty_url
    url = "#{search_catalog_path}&f%5Bformat_f%5D%5B%5D=Database+%26+Article+Index"
    redirect_to url
  end

end
