# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::Tokens::ScimAccessToken, :aggregate_failures, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:scim_oauth_token) { create(:scim_oauth_access_token, organization: organization) }
  let_it_be(:group_scim_token) { create(:group_scim_auth_access_token, group: group) }

  describe '.prefix?' do
    context 'with valid SCIM token prefixes' do
      it 'returns true for ScimOauthAccessToken tokens' do
        expect(described_class.prefix?(scim_oauth_token.token)).to be true
      end

      it 'returns true for GroupScimAuthAccessToken tokens' do
        expect(described_class.prefix?(group_scim_token.token)).to be true
      end

      it 'returns true for tokens with custom instance prefix' do
        stub_application_setting(instance_token_prefix: 'custom')
        custom_oauth_token = create(:scim_oauth_access_token, organization: organization).token
        custom_group_token = create(:group_scim_auth_access_token, group: group).token

        expect(described_class.prefix?(custom_oauth_token)).to be true
        expect(described_class.prefix?(custom_group_token)).to be true
      end

      it 'returns false for tokens with instance prefix when custom_prefix_for_all_token_types is disabled' do
        stub_feature_flags(custom_prefix_for_all_token_types: false)
        stub_application_setting(instance_token_prefix: 'custom')
        # When feature flag is disabled, tokens should not have instance prefix
        # So we manually create tokens with instance prefix to test the negative case
        token_with_instance_prefix = "custom-#{::ScimOauthAccessToken::TOKEN_PREFIX}-testtoken"
        group_token_with_instance_prefix = "custom-#{::GroupScimAuthAccessToken::TOKEN_PREFIX}-testtoken"

        expect(described_class.prefix?(token_with_instance_prefix)).to be false
        expect(described_class.prefix?(group_token_with_instance_prefix)).to be false
      end
    end

    context 'with invalid token prefix' do
      it 'returns false for random strings' do
        expect(described_class.prefix?('random_string')).to be false
      end

      it 'returns false for other token types' do
        personal_access_token = create(:personal_access_token).token
        expect(described_class.prefix?(personal_access_token)).to be false
      end
    end
  end

  describe '#initialize' do
    context 'with ScimOauthAccessToken' do
      subject(:token) { described_class.new(scim_oauth_token.token, :secret_detection) }

      it 'finds the correct token' do
        expect(token.revocable).to eq(scim_oauth_token)
      end

      it 'stores the source' do
        expect(token.source).to eq(:secret_detection)
      end
    end

    context 'with GroupScimAuthAccessToken' do
      subject(:token) { described_class.new(group_scim_token.token, :secret_detection) }

      it 'finds the correct token' do
        expect(token.revocable).to eq(group_scim_token)
      end

      it 'stores the source' do
        expect(token.source).to eq(:secret_detection)
      end
    end

    context 'with non-existent token' do
      subject(:token) { described_class.new('glsoat-nonexistent', :secret_detection) }

      it 'sets revocable to nil' do
        expect(token.revocable).to be_nil
      end
    end
  end

  describe '#present_with' do
    context 'with ScimOauthAccessToken' do
      subject(:token) { described_class.new(scim_oauth_token.token, :secret_detection).present_with }

      it 'returns the ScimOauthAccessToken entity class' do
        expect(token).to eq(::API::Entities::ScimOauthAccessToken)
      end
    end

    context 'with GroupScimAuthAccessToken' do
      subject(:token) { described_class.new(group_scim_token.token, :secret_detection).present_with }

      it 'returns the GroupScimAuthAccessToken entity class' do
        expect(token).to eq(::API::Entities::GroupScimAuthAccessToken)
      end
    end

    context 'with non-existent token' do
      subject(:token) { described_class.new('glsoat-nonexistent', :secret_detection).present_with }

      it 'returns nil when revocable is nil' do
        expect(token).to be_nil
      end
    end
  end

  describe '#revoke!' do
    let_it_be(:admin) { create(:admin) }

    context 'with ScimOauthAccessToken' do
      let(:revocable) { create(:scim_oauth_access_token, organization: organization) }

      subject(:token) { described_class.new(revocable.token, :api_admin_token) }

      it 'resets the token' do
        old_token = revocable.token

        response = token.revoke!(admin)

        expect(response).to be_a(ServiceResponse)
        expect(response.success?).to be true
        expect(revocable.reload.token).not_to eq(old_token)
      end
    end

    context 'with GroupScimAuthAccessToken' do
      let(:revocable) { create(:group_scim_auth_access_token, group: group) }

      subject(:token) { described_class.new(revocable.token, :api_admin_token) }

      it 'resets the token' do
        old_token = revocable.token

        response = token.revoke!(admin)

        expect(response).to be_a(ServiceResponse)
        expect(response.success?).to be true
        expect(revocable.reload.token).not_to eq(old_token)
      end
    end

    context 'with non-existent token' do
      subject(:token) { described_class.new('glsoat-nonexistent', :api_admin_token) }

      it 'raises NotFoundError' do
        expect { token.revoke!(admin) }.to raise_error(::Authn::AgnosticTokenIdentifier::NotFoundError)
      end
    end
  end
end
