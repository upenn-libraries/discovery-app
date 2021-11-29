# frozen_string_literal: true

module Illiad
  # Represent an Illiad request
  class Request
    attr_accessor :user_id, :email, :note

    OFFICE_DELIVERY = 'office'
    MAIL_DELIVERY = 'mail'
    ELECTRONIC_DELIVERY = 'electronic'

    # @param [Hash] user
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [Hash] params
    def initialize(user, item, params)
      @user_id = user[:id]
      @email = user[:email]
      @item = item
      @data = params
      @delivery = params
      @note = params[:comments]
    end

    def type
      :illiad
    end

    # for POSTing to API
    # @return [Hash]
    def to_h
      if scan_deliver?
        scandelivery_request_body @user_id, @item, @data
      else
        book_request_body @user_id, @item, @data
      end
    end

    # @return [String]
    def delivery
      @data.dig :delivery
    end

    private

    # Is this request a Scan & Deliver request?
    # @return [TrueClass, FalseClass]
    def scan_deliver?
      @data.dig('delivery') == ELECTRONIC_DELIVERY
    end

    def book_request_body(user_id, item, data)
      body = {
        Username: user_id,
        RequestType: 'Loan',
        ProcessType: 'Borrowing',
        DocumentType: 'Book',
        LoanAuthor: item&.bib('author'),
        LoanTitle: item&.bib('title') || data[:bib_title],
        LoanPublisher: item&.bib('publisher_const'),
        LoanPlace: item&.bib('place_of_publication'),
        LoanDate: item&.bib('date_of_publication'),
        LoanEdition: item&.bib('complete_edition'),
        ISSN: item&.bib('issn') || item&.bib('isbn') || data[:isxn],
        CitedIn: cited_in_value
      }
      append_routing_info body
    end

    def scandelivery_request_body(user_id, item, data)
      {
        Username: user_id,
        ProcessType: 'Borrowing',
        DocumentType: 'Article',
        PhotoJournalTitle: item&.bib('title') || data[:bib_title],
        PhotoJournalVolume: data[:section_volume],
        PhotoJournalIssue: data[:section_issue],
        PhotoJournalMonth: item&.pub_month,
        PhotoJournalYear: item&.pub_year,
        PhotoJournalInclusivePages: data['pages'],
        ISSN: item&.bib('issn') || item&.bib('isbn') || data[:isxn],
        PhotoArticleAuthor: data[:section_author],
        PhotoArticleTitle: data[:section_title],
        CitedIn: cited_in_value
      }
    end

    def cited_in_value
      'info:sid/primo.exlibrisgroup.com'
    end

    # @param [Hash] body
    # @return [Hash]
    def append_routing_info(body)
      if @data[:delivery] == MAIL_DELIVERY
        # BBM attribute changes to trigger Illiad routing rules
        body[:LoanTitle] = body[:LoanTitle].prepend('BBM ')
        body[:ItemInfo1] = 'Books by Mail'
      elsif @data[:delivery] == OFFICE_DELIVERY
        # Also set ItemInfo1 to BBM for Office delivery
        # It doesn't make sense, but this is what Lapis desires
        body[:ItemInfo1] = 'Books by Mail'
      end
      body
    end
  end
end
