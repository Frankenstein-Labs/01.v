# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BotBypassChecker, feature_category: :security_policy_management do
  let(:bypass_settings) { {} }
  let(:policy) do
    create(:security_policy, content: { bypass_settings: bypass_settings })
  end

  subject(:checker) { described_class.new(bypass_settings: policy.bypass_settings, user: user) }

  describe '#bypass_allowed?' do
    context 'when user is nil' do
      let(:user) { nil }

      it { expect(checker.bypass_allowed?).to be false }
    end

    context 'when user is a regular user' do
      let(:user) { create(:user) }

      it { expect(checker.bypass_allowed?).to be false }

      context 'when user is in bypass_settings users' do
        let(:bypass_settings) { { users: [{ id: user.id }] } }

        it { expect(checker.bypass_allowed?).to be false }
      end
    end

    context 'when user is a service account' do
      let(:user) { create(:user, :service_account) }

      context 'when service account is not in bypass_settings' do
        it { expect(checker.bypass_allowed?).to be false }
      end

      context 'when service account is in bypass_settings' do
        let(:bypass_settings) { { service_accounts: [{ id: user.id }] } }

        it { expect(checker.bypass_allowed?).to be true }
      end

      context 'when a different service account is in bypass_settings' do
        let(:other_service_account) { create(:user, :service_account) }
        let(:bypass_settings) { { service_accounts: [{ id: other_service_account.id }] } }

        it { expect(checker.bypass_allowed?).to be false }
      end
    end

    context 'when user is a project bot (access token)' do
      let(:user) { create(:user, :project_bot) }
      let!(:personal_access_token) { create(:personal_access_token, user: user) }

      context 'when access token is not in bypass_settings' do
        it { expect(checker.bypass_allowed?).to be false }
      end

      context 'when access token is in bypass_settings' do
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        it { expect(checker.bypass_allowed?).to be true }
      end

      context 'when a different access token is in bypass_settings' do
        let(:other_token) { create(:personal_access_token) }
        let(:bypass_settings) { { access_tokens: [{ id: other_token.id }] } }

        it { expect(checker.bypass_allowed?).to be false }
      end

      context 'when access token is revoked' do
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        before do
          personal_access_token.revoke!
        end

        it { expect(checker.bypass_allowed?).to be false }
      end
    end
  end

  describe '#service_account_id' do
    context 'when user is a regular user' do
      let(:user) { create(:user) }

      it { expect(checker.service_account_id).to be_nil }
    end

    context 'when user is a service account' do
      let(:user) { create(:user, :service_account) }

      context 'when service account is not in bypass_settings' do
        it { expect(checker.service_account_id).to be_nil }
      end

      context 'when service account is in bypass_settings' do
        let(:bypass_settings) { { service_accounts: [{ id: user.id }] } }

        it { expect(checker.service_account_id).to eq(user.id) }
      end
    end
  end

  describe '#access_token_ids' do
    context 'when user is a regular user' do
      let(:user) { create(:user) }

      it { expect(checker.access_token_ids).to be_nil }
    end

    context 'when user is a project bot' do
      let(:user) { create(:user, :project_bot) }
      let!(:personal_access_token) { create(:personal_access_token, user: user) }

      context 'when access token is not in bypass_settings' do
        it { expect(checker.access_token_ids).to be_nil }
      end

      context 'when access token is in bypass_settings' do
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        it { expect(checker.access_token_ids).to eq([personal_access_token.id]) }
      end

      context 'when multiple access tokens exist and some are in bypass_settings' do
        let!(:another_token) { create(:personal_access_token, user: user) }
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        it { expect(checker.access_token_ids).to eq([personal_access_token.id]) }
      end

      context 'when access token is revoked' do
        let(:bypass_settings) { { access_tokens: [{ id: personal_access_token.id }] } }

        before do
          personal_access_token.revoke!
        end

        it { expect(checker.access_token_ids).to be_nil }
      end
    end
  end
end
