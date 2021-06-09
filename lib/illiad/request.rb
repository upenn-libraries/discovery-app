# frozen_string_literal: true

module Illiad
  # Represent an Illiad request
  class Request
    attr_accessor :recipient_username, :submitter_email, :submitter_username

    CAMPUS_DELIVERY = 'campus'
    MAIL_DELIVERY = 'bbm'
    ELECTRONIC_DELIVERY = 'electronic'

    # @param [Hash] user
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [Hash] params
    def initialize(user, item, params)
      @recipient_username = params[:deliver_to].presence || user[:id]
      @submitter_username = user[:id]
      @submitter_email = user[:email]
      @item = item
      @data = params
    end

    # for POSTing to API
    # @return [Hash]
    def to_h
      body = if scan_deliver?
               scandelivery_request_body @recipient_username, @item, @data
             else
               book_request_body @recipient_username, @item, @data
             end
      return body unless proxied?

      append_proxy_info_to_comments body
    end

    private

    # Is this request a Scan & Deliver request?
    # @return [TrueClass, FalseClass]
    def scan_deliver?
      @data.dig('delivery') == ELECTRONIC_DELIVERY
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
        ISSN: item.bib('issn') || item.bib('isbn'),
        # ESPNumber: data['pmid'],
        Notes: data[:comments],
        CitedIn: cited_in_value
      }
      append_routing_info body
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
        body[:LoanTitle] = body['LoanTitle'].prepend('BBM ')
        body[:ItemInfo1] = 'booksbymail'
      elsif @data[:delivery] == CAMPUS_DELIVERY
        # likewise for campus delivery
        body[:ItemInfo1] = 'campus'
      end
      body
    end

    # @return [TrueClass, FalseClass]
    def proxied?
      @recipient_username != @submitter_username
    end

    # @param [Hash] body
    # @return [Hash]
    def append_proxy_info_to_comments(body)
      body['Notes'] += "\nProxy request submitted by #{@submitter_username}"
      body
    end
  end
end
