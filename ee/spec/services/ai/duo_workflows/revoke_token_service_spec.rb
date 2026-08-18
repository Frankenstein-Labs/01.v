# frozen_string_literal: true

require 'spec_helper'
RSpec.describe ::Ai::DuoWorkflows::RevokeTokenService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:another_user) { create(:user) }

    it 'returns success when token to revoke is invalid' do
      result = described_class.new(token: "not-a-valid-token", current_user: user).execute

      expect(result[:status]).to eq(:success)
    end

    it 'returns error when token to revoke does not belong to current user' do
      token = create(:oauth_access_token, user: another_user, scopes: ['ai_workflows'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:invalid_token_ownership)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns error when token to revoke does not have ai_workflows scope' do
      token = create(:oauth_access_token, user: user, scopes: ['api'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:insufficient_token_scope)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns error when token could not be revoked' do
      token = create(:oauth_access_token, user: user, scopes: ['ai_workflows'])

      allow(Doorkeeper::AccessToken).to receive(:by_token).with(token.plaintext_token).and_return(token)
      allow(token).to receive(:revoke).and_return(false)

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:failed_to_revoke)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns success when token could be revoked' do
      token = create(:oauth_access_token, user: user, scopes: ['ai_workflows'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:success)
      expect(token.reload.revoked?).to be(true)
    end

    context 'with composite identity' do
      let_it_be(:service_account) { create(:service_account, composite_identity_enforced: true) }
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:another_user) { create(:user) }

      it 'returns success when token belongs to service account but has user scope matching current user' do
        token = create(:oauth_access_token,
          resource_owner: service_account,
          scopes: ['ai_workflows', "user:#{regular_user.id}"]
        )

        result = described_class.new(token: token.plaintext_token, current_user: regular_user).execute

        expect(result[:status]).to eq(:success)
        expect(token.reload.revoked?).to be(true)
      end

      it 'returns error when token has user scope but does not match current user' do
        token = create(:oauth_access_token,
          resource_owner: service_account,
          scopes: ['ai_workflows', "user:#{another_user.id}"]
        )

        result = described_class.new(token: token.plaintext_token, current_user: regular_user).execute

        expect(result[:status]).to eq(:error)
        expect(result[:reason]).to eq(:invalid_token_ownership)
        expect(token.reload.revoked?).to be(false)
      end

      it 'returns error when token belongs to service account but has no user scope' do
        token = create(:oauth_access_token,
          resource_owner: service_account,
          scopes: ['ai_workflows']
        )

        result = described_class.new(token: token.plaintext_token, current_user: regular_user).execute

        expect(result[:status]).to eq(:error)
        expect(result[:reason]).to eq(:invalid_token_ownership)
        expect(token.reload.revoked?).to be(false)
      end

      it 'returns error when user scope has invalid format' do
        token = create(:oauth_access_token,
          resource_owner: service_account,
          scopes: ['ai_workflows', 'user:invalid']
        )

        result = described_class.new(token: token.plaintext_token, current_user: regular_user).execute

        expect(result[:status]).to eq(:error)
        expect(result[:reason]).to eq(:invalid_token_ownership)
        expect(token.reload.revoked?).to be(false)
      end

      it 'returns error when service account does not have composite identity enforced' do
        service_account_without_ci = create(:service_account, composite_identity_enforced: false)
        token = create(:oauth_access_token,
          resource_owner: service_account_without_ci,
          scopes: ['ai_workflows', "user:#{regular_user.id}"]
        )

        result = described_class.new(token: token.plaintext_token, current_user: regular_user).execute

        expect(result[:status]).to eq(:error)
        expect(result[:reason]).to eq(:invalid_token_ownership)
      end
    end
  end
end
