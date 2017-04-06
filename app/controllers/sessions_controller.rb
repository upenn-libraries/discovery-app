
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin

  # shib should protect the path for this action, redirecting the user to authenticate with PennKey;
  # after the user has authenticated, they hit this action for real, which logs them into discovery
  # and redirects them to the URL specified by 'next' param
  def sso_login_callback
    next_url = params[:next] || '/'
    # log user into devise for now

    # TODO: figure out what we should do to make the user considered "logged in"
    # TODO: how to get user's email?
    user = User.find_or_create_by(email: 'fake@fake.com')

    sign_in(:user, user)
    # set warden user manually
    env['warden'].set_user(user)

    session[:alma_auth_type] = 'sso'
    # TODO: generate a secret
    session[:alma_sso_token] = 'blah'

    redirect_to next_url
  end

end
