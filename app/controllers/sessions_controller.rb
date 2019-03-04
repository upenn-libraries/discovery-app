
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

  SHIB_IDP_LOGOUT_PAGE = 'https://idp.pennkey.upenn.edu/logout'

  def set_session_userid(id)
    session['id'] = id
  end

  def set_session_user_details(id)
    if id
      api_instance = BlacklightAlma::UsersApi.instance
      api = api_instance.ezwadl_api[0]
      url = api.almaws_v1_users.user_id.uri_template({ user_id: id}).chomp("/")
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
      #
      #response = BlacklightAlma::UsersApi.instance.get_name(id)

      if response.code == 200
        if response && response['user']
          session['first_name'] = response['user']['first_name']
          session['user_group'] = response['user']['user_group']['desc']
        end
      else
        Rails.logger.error("ERROR: Got non-200 response from Alma User API, user account may not exist for id=#{id}. response=#{response}")
      end
    end
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
