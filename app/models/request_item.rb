# frozen_string_literal: true

# a representation of an item suitable for creating a Request (AbstractRequest? IlliadRequest?)
class RequestItem

  MAPPED_ILL_FORM_ELEMENTS = %w[
    title edition author publisher pub_place pub_date isxn citation_source
    journal_title article_title date volume issue pages
  ]

  BOOK_TYPE = 'book'
  ARTICLE_TYPE = 'article'

  delegate *MAPPED_ILL_FORM_ELEMENTS, to: :@source_object

  def populate_from(params)
    @params = params
    @source_object = if mmsid_from_params
                       build_from_alma_bib
                     else
                       build_from_openurl_params
                     end
  end

  def build_from_openurl_params
    OpenURLItem.new @params
  end

  def build_from_alma_bib
    BibRequest.new mmsid_from_params
  end

  def type
    if book_request?
      return BOOK_TYPE
    end

    ARTICLE_TYPE
  end

  private

  def book_request?
    @params[:requesttype] == 'book'
  end

  def mmsid_from_params
    @params[:bibid].presence || @params[:mmsid].presence
  end
end
