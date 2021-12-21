
module HandleInvalidAdvancedSearch

  extend ActiveSupport::Concern

  FIELD_LENGTH_CAP = ENV.fetch('FIELD_LENGTH_CAP', 200).to_i
  # TODO: read this out of the BL config (it's hard-coded for now)
  CONFIGURED_FIELDS = %w[
    keyword
    title_search
    journal_title_search
    author_search
    subject_search
    genre_search
    isxn_search
    series_search
    publisher_search
    place_of_publication_search
    conference_search
    corporate_author_search
    pubnum_search
    call_number_search
    language_search
    contents_note_search
    id_search
    mms_id
  ]

  # override
  def search_results(params)
    # the most common cause of ParseFailed exceptions = search params
    # with unbalanced quotes. we re-raise as InvalidRequest exceptions
    # so BL handles them somewhat meaningfully. this avoids a 500 page.

    # Limit the size of each configured field
    CONFIGURED_FIELDS.each do |key|
      val = params[key]
      if val && val.length > FIELD_LENGTH_CAP
        raise Blacklight::Exceptions::InvalidRequest, "field value for #{key} exceeded maximum length #{FIELD_LENGTH_CAP}"
      end
    end

    begin
      super(params)
    rescue Parslet::ParseFailed => e
      raise Blacklight::Exceptions::InvalidRequest, e.message
    end
  end

end
