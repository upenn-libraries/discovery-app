# frozen_string_literal: true

module TurboAlmaApi
  # Represent a Franklin Request submission destined for Alma
  class Request

    attr_accessor :mms_id, :holding_id, :item_pid, :item
    attr_accessor :pickup_location, :pickup_location_human, :comments

    PICKUP_LOCATIONS = [
      ['Van Pelt Library', 'VanPeltLib'],
      ['Lockers at Van Pelt Library', 'VPLOCKER'],
      ['Annenberg Library', 'AnnenLib'],
      ['Athenaeum Library', 'AthLib'],
      ['Holman Biotech Commons', 'BiomLib'],
      ['Chemistry Library', 'ChemLib'],
      ['Dental Medicine Library', 'DentalLib'],
      ['Lockers at Dental Medicine Library', 'DENTLOCKER'],
      ['Fisher Fine Arts Library', 'FisherFAL'],
      ['Library at the Katz Center', 'KatzLib'],
      ['Math/Physics/Astronomy Library', 'MPALib'],
      ['Museum Library', 'MuseumLib'],
      ['Ormandy Music and Media Center', 'MusicLib'],
      ['Pennsylvania Hospital Library - PAH Staff Only', 'PAHospLib'],
      ['Veterinary Library - New Bolton Center', 'VetNBLib'],
      ['Veterinary Library - Penn Campus', 'VetPennLib'],
    ]

    # @param [Hash] user
    # @param [TurboAlmaApi::Bib::PennItem] item
    # @param [Hash] params
    def initialize(user, item = nil, params = {})
      @user = user
      @item = item
      @mms_id = params[:mms_id]
      @holding_id = params[:holding_id]
      @item_pid = params[:item_pid]
      @comments = params[:comments]
      @pickup_location = determine_pickup_location(params)
      @pickup_location_human = pickup_location_human
    end

    def type
      :alma
    end

    # @return [String]
    def user_id
      @user[:id]
    end

    # @return [String]
    def email
      @user[:email]
    end

    # @return [String (frozen)]
    # @param [ActionController::Parameters] params
    def determine_pickup_location(params)
      params[:pickup_location]&.to_s || 'VanPeltLib'
    end

    def pickup_location_human
      location_info = PICKUP_LOCATIONS.find { |loc_arr| loc_arr[1] == @pickup_location }
      location_info&.first
    end
  end
end
