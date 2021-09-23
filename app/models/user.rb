class User < ActiveRecord::Base

  if Blacklight::Utils.needs_attr_accessible?
    attr_accessible :email, :password, :password_confirmation
  end

  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User

  # a minimal set of devise modules are enabled here, as we handle auth
  # "manually" and User records are merely stubs
  devise :database_authenticatable, :rememberable, :trackable

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    email
  end
end
