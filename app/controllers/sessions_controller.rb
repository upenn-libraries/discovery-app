
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

  SHIB_IDP_LOGOUT_PAGE = 'https://idp.pennkey.upenn.edu/logout'

  def set_session_userid(id)
    session['id'] = id
  end

  def set_session_user_details(id)
    return unless id

    alma_user = TurboAlmaApi::User.new id
    session['first_name'] = alma_user.first_name
    session['user_group'] = alma_user.user_group
    session['email'] = alma_user.email

  rescue TurboAlmaApi::User::UserNotFound
    flash[:alert] = "The credentials you have entered to authenticate are not registered in our library system. Please contact the circulation desk at vpcircdk@pobox.upenn.edu for assistance." # temporarily removed "or 215-898-7566"
    Rails.logger.error("ERROR: Got non-200 response from Alma User API, user account may not exist for id=#{id}. response=#{response}")
  end

  def social_login_populate_session(jwt)
    super(jwt)
    session['hard_expiration'] = jwt['exp']

    set_session_user_details(jwt['id'])
    set_session_userid(jwt['id'])
  end

  def sso_login_populate_session
    super
    # TODO: a PennKey session expires in 10 hours, but could be less if the user is
    # already authenticated when they hit shibboleth? maybe? we may need to
    # adjust this to be deliberately lower.
    session['hard_expiration'] = Time.now.to_i + (10 * 60 * 60)

    # TODO: this can lead to 'none' being set as the session userid
    # which breaks some Alma lookups for guest users. Removing this
    # and not setting session user info for guest users is probably
    # the right thing to do but needs testing in a production-like
    # environment
    remote_user_header = request.headers['HTTP_REMOTE_USER'] || 'none@upenn.edu'
    pennkey_username = remote_user_header.split('@').first
    set_session_user_details(pennkey_username)
    set_session_userid(pennkey_username)
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
