
# This mixin strips out invalid UTF8 characters in the 'q' param for searches.
# This prevents "invalid byte sequence in UTF-8" exceptions.
#
# These cases only happen when other (Penn library) sites construct Franklin URLs.
# I'm looking at you, https://portal.apps.upenn.edu/penn_portal/portal.php?tabid=1431
# Including the %A0 char is a common case.
module ReplaceInvalidBytes

  extend ActiveSupport::Concern

  included do
    before_action :replace_invalid_bytes_in_q
  end

  def replace_invalid_bytes_in_q
    if params[:q]
      params[:q] = params[:q].encode('UTF-8', invalid: :replace, replace: '')
    end
  end

end
