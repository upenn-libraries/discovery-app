
class SessionsController < Devise::SessionsController

  include BlacklightAlma::SocialLogin

end
