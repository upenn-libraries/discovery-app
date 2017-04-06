
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin
  include BlacklightAlma::Sso

end
