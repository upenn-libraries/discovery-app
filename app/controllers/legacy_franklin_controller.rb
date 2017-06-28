
class LegacyFranklinController < ApplicationController

  ALMA_MMS_ID_PREFIX = '99'
  ALMA_MMS_ID_SUFFIX = '3503681'

  # redirect for old /record.html URLs
  def record
    new_id = params[:id]
    if new_id
      if new_id.start_with?('FRANKLIN')
        new_id = new_id.sub(/(\d+)/, "#{ALMA_MMS_ID_PREFIX}\\1#{ALMA_MMS_ID_SUFFIX}")
      end
      redirect_to "https://franklin.library.upenn.edu/catalog/#{new_id}"
    else
      redirect_to 'https://franklin.library.upenn.edu/'
    end
  end

  def redirect_to_root
    redirect_to 'https://franklin.library.upenn.edu/'
  end

  def dla_subpaths
    # trim off querystring portion
    path = request.fullpath.split('?')[0]
    # return 404 for stuff like images, css, js
    if path.end_with?('.css') ||
      path.end_with?('.gif') ||
      path.end_with?('.jpg') ||
      path.end_with?('.js') ||
      path.end_with?('.png')
      raise ActionController::RoutingError.new('Not Found')
    else
      redirect_to_root
    end
  end

end
