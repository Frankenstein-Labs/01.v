# frozen_string_literal: true

class ScimOauthAccessToken < ApplicationRecord
  include TokenAuthenticatable

  TOKEN_PREFIX = 'glsoat-'

  belongs_to :organization, class_name: 'Organizations::Organization'
  belongs_to :group, optional: true

  add_authentication_token_field :token, encrypted: :required, format_with_prefix: :prefix_for_token

  validates :organization_id, presence: true, on: :create, if: -> { group_id.blank? }

  before_save :ensure_token

  def self.token_matches_for_group?(token, group)
    # Necessary to call `Authn::TokenField::Encrypted.find_token_authenticatable`
    token = find_by_token(token)

    token && group && token.group_id == group.id
  end

  def self.token_matches_for_instance?(token)
    # Necessary to call `Authn::TokenField::Encrypted.find_token_authenticatable`
    token = find_by_token(token)
    # This method is for authenticating with instance-level SCIM tokens. As a
    # result, group SCIM tokens should return falsey value
    token && !token.group_id
  end

  def self.find_for_instance
    find_by_group_id(nil)
  end

  def self.prefix_for_token
    ::Authn::TokenField::PrefixHelper.prepend_instance_prefix(TOKEN_PREFIX)
  end

  def as_entity_json
    ScimOauthAccessTokenEntity.new(self).as_json
  end

  def prefix_for_token
    self.class.prefix_for_token
  end
end
