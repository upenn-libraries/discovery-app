
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

  def social_login_populate_session(jwt)
    super(jwt)
    session['hard_expiration'] = jwt['exp']
  end

  def sso_login_populate_session
    super
    # TODO: a PennKey session expires in 10 hours, but could be less if the user is
    # already authenticated when they hit shibboleth? maybe? we may need to
    # adjust this to be deliberately lower.
    session['hard_expiration'] = Time.now.to_i + (10 * 60 * 60)
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
      redirect_to "/Shibboleth.sso/Logout?return=#{root_url}"
    else
      super
    end
  end

end
