
class AccountsController < ApplicationController

  def login
    next_url = params[:next]
    # log user into devise for now

    # TODO: figure out what we should do to make the user considered "logged in"

    #sign_in(:user, user)
    # set warden user manually
    #env['warden'].set_user(user)

    session[:alma_auth_type] = 'sso'

    redirect_to next_url
  end

  def logout

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

end
