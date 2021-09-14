# frozen_string_literal: true

module TurboAlmaApi
  # sort the wheat from the chaff in Alma's User API response
  class User
    class Timeout < StandardError; end
    class UserNotFound < StandardError; end

    attr_reader :pennkey, :id, :name, :first_name, :last_name, :email,
                :user_group, :affiliation, :organization, :active

    # @param [String] user_id
    # @return [AlmaUser]
    def initialize(user_id)
      @pennkey = user_id
      user_record = get_user user_id
      @id = user_record.id
      @name = user_record.full_name
      @first_name = user_record.preferred_first_name.titleize
      @last_name = user_record.preferred_last_name.titleize
      @email = safe_preferred_email_from user_record
      @user_group = user_group_from user_record
      @affiliation = affiliation_from user_record
      @organization = organization_from user_record
      @active = active_from user_record
    rescue StandardError => e
      raise UserNotFound,
            "Username '#{user_id}' cannot be created. Are you sure the Pennkey is valid? Exception: #{e.message}"
    end

    # Get preferred email, handling error if one is not present
    # @param [Object] user_record
    # @return [Alma::User, NilClass]
    def safe_preferred_email_from(user_record)
      user_record.preferred_email
    rescue NoMethodError => _e
      nil
    end

    # @return [Hash{Symbol->Unknown}]
    def to_h
      { id: id, name: name, email: email, user_group: user_group,
        affiliation: affiliation, organization: organization }
    end

    private

    # @param [String] user_id
    # @return [Alma::User]
    def get_user(user_id)
      Alma::User.find user_id, expand: nil
    rescue Alma::User::ResponseError => e
      raise e
    rescue Net::OpenTimeout => e
      raise TurboAlmaApi::User::Timeout, "Problem with Alma API: #{e.message}"
    end

    def user_group_from(user_record)
      user_record.user_group['desc']
    end

    def affiliation_from(user_record)
      affiliation_stat = user_record.user_statistic&.find do |stat|
        stat.dig('category_type', 'value') == 'AFFILIATION'
      end
      affiliation_stat&.dig 'statistic_category', 'desc'
    end

    def organization_from(user_record)
      organization_stat = user_record.user_statistic&.find do |stat|
        stat.dig('category_type', 'value') == 'ORG'
      end
      organization_stat&.dig 'statistic_category', 'desc'
    end

    def active_from(user_record)
      user_record.status.dig('value') == 'ACTIVE'
    end
  end
end
