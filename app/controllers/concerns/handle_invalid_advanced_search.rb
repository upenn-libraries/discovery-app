
module HandleInvalidAdvancedSearch

  extend ActiveSupport::Concern

  # override
  def search_results(params)
    # the most common cause of ParseFailed exceptions = search params
    # with unbalanced quotes. we re-raise as InvalidRequest exceptions
    # so BL handles them somewhat meaningfully. this avoids a 500 page.
    begin
      super(params)
    rescue Parslet::ParseFailed => e
      raise Blacklight::Exceptions::InvalidRequest, e.message
    end
  end

end
