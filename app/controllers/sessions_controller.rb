
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
    # already authenticated when they hit shibboleth. we need to handle this: it would
    # be ideal if shib gave us an expiration time
    session['hard_expiration'] = Time.now.to_i + (10 * 60 * 60)
  end

end
