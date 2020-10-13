# This file contains overrides of gem behavior from
# both Devise and BlacklightAlma
class SessionsController < Devise::SessionsController
  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

  SHIB_IDP_LOGOUT_PAGE = 'https://idp.pennkey.upenn.edu/logout'.freeze

  # Sets user info in session after a 'Social'-initiated login. This extends the
  # behavior of the method in BlacklightAlma::SocialLogin
  def social_login_populate_session(jwt)
    super(jwt)
    session['id'] = jwt['id']
    session['hard_expiration'] = jwt['exp']
    augment_session_user_details jwt['id']
  end

  # Sets user info in session after an SSO-initiated login. This extends the
  # behavior of the method in BlacklightAlma::Sso
  def sso_login_populate_session
    super
    # TODO: a PennKey session expires in 10 hours, but could be less if the user is
    # already authenticated when they hit shibboleth? maybe? we may need to
    # adjust this to be deliberately lower.
    session['hard_expiration'] = Time.now.to_i + (10 * 60 * 60)
    username = username_from_headers_or_env
    session['id'] = username
    augment_session_user_details username
  end

  # override from Devise::Controllers::SignInOut to
  # save the auth type before devise destroys the session
  def sign_out(resource_or_scope = nil)
    @alma_auth_type = session[:alma_auth_type]
    super(resource_or_scope)
  end

  # override from Devise to redirect to PennKey logout when user has signed in
  # via SSO
  def respond_to_on_destroy
    if @alma_auth_type == 'sso'
      redirect_to "/Shibboleth.sso/Logout?return=#{URI.encode(SHIB_IDP_LOGOUT_PAGE)}"
    else
      super
    end
  end

  private

  # Set user first name and Alma user_group in session by making Alma API call
  def augment_session_user_details(id)
    return unless id

    api = BlacklightAlma::UsersApi.instance.ezwadl_api[0]
    url = api.almaws_v1_users.user_id.uri_template({ user_id: id }).chomp('/')
    url += "?apikey=#{ENV['ALMA_API_KEY']}"
    response = HTTParty.get(url)

    # At some point, ExLibris changed the behavior of the API used to retrieve
    # user details such that if a trailing slash is present in the URL, it
    # treats it as part of the username (ex. "clemenc/"). Since no username has
    # a trailing slash this always fails. To work around this, I've replaced the
    # commented outline below with the block above and have opened a SalesForce
    # case (#00000000). If ExLibris restores the old behavior, we can start using
    # the line below again. Otherwise we should either alter the underlying EzWadl
    # gem to not add a # trailing slash if it is not present in the parsed WADL or
    # handle this edge case in the blacklight_alma gem.
    # As of 10/2020, the below line still returns an error
    #
    # response = BlacklightAlma::UsersApi.instance.get_name(id)

    if response.success?
      session['first_name'] = response.dig 'user', 'first_name'
      session['user_group'] = response.dig 'user', 'user_group', 'desc'
    else
      # temporarily removed "or 215-898-7566"
      flash[:alert] = 'The credentials you have entered to authenticate are not registered in our library system. Please contact the circulation desk at vpcircdk@pobox.upenn.edu for assistance.'
      Rails.logger.error("ERROR: Got non-200 response from Alma User API, user account may not exist for id=#{id}. response=#{response}")
    end
  end

  # Extract username from SSO-provided HTTP header value for production
  # Otherwise, return username from ENV var for dev & test convenience
  # @return [String]
  def username_from_headers_or_env
    if Rails.env.production?
      headers_username = request.headers['HTTP_REMOTE_USER']
      headers_username.split('@').first
    else
      ENV['DEVELOPMENT_USERNAME']
    end
  end
end
