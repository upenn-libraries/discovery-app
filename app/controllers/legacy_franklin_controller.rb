
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

  def dla
    redirect_to 'https://franklin.library.upenn.edu/'
  end

end
