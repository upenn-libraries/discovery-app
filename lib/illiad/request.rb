# frozen_string_literal: true

module Illiad
  # Represent an Illiad request
  class Request
    attr_accessor :recipient_username

    # @param [String] user_id
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [ActionController::Parameters] params
    def initialize(user_id, item, params)
      @recipient_username = params[:deliver_to].presence || user_id
      @item = item
      @data = params
    end

    # for POSTing to API
    # @return [Hash]
    def to_h
      if scan_deliver?
        scandelivery_request_body @recipient_username, @item, @data
      else
        book_request_body @recipient_username, @item, @data
      end
    end

    private

    # Is this request a Scan & Deliver request?
    # @return [TrueClass, FalseClass]
    def scan_deliver?
      @data.dig('delivery') == 'scandeliver'
    end

    def book_request_body(username, item, data)
      body = {
        Username: username,
        ProcessType: 'Borrowing',
        LoanAuthor: item.bib('author'),
        LoanTitle: item.bib('title'),
        LoanPublisher: item.bib('publisher_const'),
        LoanPlace: item.bib('place_of_publication'),
        LoanDate: item.bib('date_of_publication'),
        LoanEdition: item.bib('complete_edition'),
        ISSN: item.bib('isbn'),
        # ESPNumber: data['pmid'],
        Notes: data[:comments],
        # CitedIn: data['sid'],
        # ItemInfo1: data['delivery_option']
      }
      return body unless @data[:delivery] == 'bbm'

      # BBM attribute changes - to trigger Illiad routing rules
      body['LoanTitle'] = body['LoanTitle'].prepend('BBM ')
      body['ItemInfo1'] = 'booksbymail'
      body
    end

    def scandelivery_request_body(username, item, data)
      {
        Username: username,
        ProcessType: 'Borrowing',
        PhotoJournalTitle: item.bib('title'),
        PhotoJournalVolume: data[:section_volume],
        PhotoJournalIssue: data[:section_issue],
        PhotoJournalMonth: item.bib('date_of_publication'),
        PhotoJournalYear: item.bib('date_of_publication'),
        PhotoJournalInclusivePages: data['pages'],
        ISSN: item.bib('issn') || item.bib('isbn'),
        # ESPNumber: data['pmid'],
        PhotoArticleAuthor: data[:section_author],
        PhotoArticleTitle: data[:section_title],
        Notes: data['comments'],
        # CitedIn: data['sid']
      }
    end
  end
end
