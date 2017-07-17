
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

  SHIB_IDP_LOGOUT_PAGE = 'https://idp.pennkey.upenn.edu/logout'

  def set_session_first_name(id)
    if id
      response = BlacklightAlma::UsersApi.instance.get_name(id)
      if response.code == 200
        if response && response['user']
          session['first_name'] = response['user']['first_name']
        end
      else
        Rails.logger.error("ERROR: Got non-200 response from Alma User API, user account may not exist for id=#{id}. response=#{response}")
      end
    end
  end

  def social_login_populate_session(jwt)
    super(jwt)
    session['hard_expiration'] = jwt['exp']

    set_session_first_name(jwt['id'])
  end

  def sso_login_populate_session
    super
    # TODO: a PennKey session expires in 10 hours, but could be less if the user is
    # already authenticated when they hit shibboleth? maybe? we may need to
    # adjust this to be deliberately lower.
    session['hard_expiration'] = Time.now.to_i + (10 * 60 * 60)

    remote_user_header = request.headers['HTTP_REMOTE_USER'] || 'none@upenn.edu'

    pennkey_username = remote_user_header.split('@').first
    set_session_first_name(pennkey_username)
  end

  # override from Devise
  def sign_out(resource_or_scope=nil)
    # save the auth type before devise destroys the session
    @alma_auth_type = session[:alma_auth_type]
    super(resource_or_scope)
  end

  # override from Devise
  def respond_to_on_destroy
    if @alma_auth_type == 'sso'
      redirect_to "/Shibboleth.sso/Logout?return=#{URI.encode(SHIB_IDP_LOGOUT_PAGE)}"
    else
      super
    end
  end

end
