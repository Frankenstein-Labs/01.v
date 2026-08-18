# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::BypassSettings, feature_category: :dependency_firewall do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:access_token) { create(:personal_access_token, user: user) }

  let(:bypass_settings_hash) do
    {
      users: [{ id: user.id }],
      access_tokens: [{ id: access_token.id }]
    }
  end

  subject(:bypass_settings) { described_class.new(bypass_settings_hash) }

  describe '#user_ids' do
    it 'returns the ids of users' do
      expect(bypass_settings.user_ids).to eq([user.id])
    end

    context 'when users is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.user_ids).to be_empty
      end
    end

    context 'with multiple users' do
      let(:bypass_settings_hash) do
        {
          users: [{ id: 100 }, { id: 200 }, { id: 300 }]
        }
      end

      it 'returns all user ids' do
        expect(bypass_settings.user_ids).to match_array([100, 200, 300])
      end
    end
  end

  describe '#access_token_ids' do
    it 'returns the ids of access tokens' do
      expect(bypass_settings.access_token_ids).to eq([access_token.id])
    end

    context 'when access_tokens is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.access_token_ids).to be_empty
      end
    end

    context 'with multiple access tokens' do
      let(:bypass_settings_hash) do
        {
          access_tokens: [{ id: 1 }, { id: 2 }, { id: 3 }]
        }
      end

      it 'returns all access token ids' do
        expect(bypass_settings.access_token_ids).to match_array([1, 2, 3])
      end
    end
  end

  describe '#service_account_ids' do
    context 'when service_accounts are present' do
      let(:bypass_settings_hash) { { service_accounts: [{ id: 10 }, { id: 20 }] } }

      it 'returns the ids of service accounts' do
        expect(bypass_settings.service_account_ids).to match_array([10, 20])
      end
    end

    context 'when service_accounts is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.service_account_ids).to be_empty
      end
    end
  end

  describe '#branches' do
    context 'when branches are present' do
      let(:bypass_settings_hash) do
        {
          branches: [{ target: { name: 'main' } }, { source: { name: 'develop' } }]
        }
      end

      it 'returns the branches array' do
        expect(bypass_settings.branches).to match_array([
          { target: { name: 'main' } }, { source: { name: 'develop' } }
        ])
      end
    end

    context 'when branches are nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.branches).to be_empty
      end
    end
  end

  describe '#group_ids' do
    context 'when groups are present' do
      let(:bypass_settings_hash) { { groups: [{ id: 300 }, { id: 400 }] } }

      it 'returns the ids of groups' do
        expect(bypass_settings.group_ids).to match_array([300, 400])
      end
    end

    context 'when groups is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.group_ids).to be_empty
      end
    end
  end

  describe '#default_roles' do
    context 'when roles are present' do
      let(:bypass_settings_hash) { { roles: %w[maintainer developer developer] } }

      it 'returns unique roles as an array' do
        expect(bypass_settings.default_roles).to match_array(%w[maintainer developer])
      end
    end

    context 'when roles is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.default_roles).to eq([])
      end
    end
  end

  describe '#custom_role_ids' do
    context 'when custom_roles are present' do
      let(:bypass_settings_hash) { { custom_roles: [{ id: 500 }, { id: 600 }] } }

      it 'returns the ids of custom roles' do
        expect(bypass_settings.custom_role_ids).to match_array([500, 600])
      end
    end

    context 'when custom_roles is nil or missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns empty array' do
        expect(bypass_settings.custom_role_ids).to be_empty
      end
    end
  end

  describe '#users_and_groups_empty?' do
    context 'when all collections are empty' do
      let(:bypass_settings_hash) { {} }

      it 'returns true' do
        expect(bypass_settings.users_and_groups_empty?).to be true
      end
    end

    context 'when user_ids is not empty' do
      let(:bypass_settings_hash) { { users: [{ id: 100 }] } }

      it 'returns false' do
        expect(bypass_settings.users_and_groups_empty?).to be false
      end
    end

    context 'when group_ids is not empty' do
      let(:bypass_settings_hash) { { groups: [{ id: 200 }] } }

      it 'returns false' do
        expect(bypass_settings.users_and_groups_empty?).to be false
      end
    end

    context 'when default_roles is not empty' do
      let(:bypass_settings_hash) { { roles: ['maintainer'] } }

      it 'returns false' do
        expect(bypass_settings.users_and_groups_empty?).to be false
      end
    end

    context 'when custom_role_ids is not empty' do
      let(:bypass_settings_hash) { { custom_roles: [{ id: 300 }] } }

      it 'returns false' do
        expect(bypass_settings.users_and_groups_empty?).to be false
      end
    end

    context 'when bypass_settings is nil' do
      subject(:bypass_settings) { described_class.new(nil) }

      it 'returns true' do
        expect(bypass_settings.users_and_groups_empty?).to be true
      end
    end
  end

  describe '#bypass_actors_empty?' do
    context 'when all collections are empty' do
      let(:bypass_settings_hash) { {} }

      it 'returns true' do
        expect(bypass_settings.bypass_actors_empty?).to be true
      end
    end

    context 'when only access_token_ids is not empty' do
      let(:bypass_settings_hash) { { access_tokens: [{ id: 1 }] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end

    context 'when only service_account_ids is not empty' do
      let(:bypass_settings_hash) { { service_accounts: [{ id: 10 }] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end

    context 'when only user_ids is not empty' do
      let(:bypass_settings_hash) { { users: [{ id: 100 }] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end

    context 'when only group_ids is not empty' do
      let(:bypass_settings_hash) { { groups: [{ id: 200 }] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end

    context 'when only default_roles is not empty' do
      let(:bypass_settings_hash) { { roles: ['maintainer'] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end

    context 'when only custom_role_ids is not empty' do
      let(:bypass_settings_hash) { { custom_roles: [{ id: 300 }] } }

      it 'returns false' do
        expect(bypass_settings.bypass_actors_empty?).to be false
      end
    end
  end

  describe '#user_bypassed?' do
    context 'when user is in bypass list' do
      it 'returns true' do
        expect(bypass_settings.user_bypassed?(user)).to be true
      end
    end

    context 'when user is not in bypass list' do
      it 'returns false' do
        expect(bypass_settings.user_bypassed?(other_user)).to be false
      end
    end

    context 'when user is nil' do
      it 'returns false' do
        expect(bypass_settings.user_bypassed?(nil)).to be false
      end
    end

    context 'when bypass list is empty' do
      let(:bypass_settings_hash) { { users: [] } }

      it 'returns false' do
        expect(bypass_settings.user_bypassed?(user)).to be false
      end
    end

    context 'when users key is missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns false' do
        expect(bypass_settings.user_bypassed?(user)).to be false
      end
    end
  end

  describe '#access_token_bypassed?' do
    context 'when user has an active access token in bypass list' do
      it 'returns truthy value' do
        expect(bypass_settings.access_token_bypassed?(user)).to be_truthy
      end
    end

    context 'when user is not in bypass list' do
      it 'returns falsy value' do
        expect(bypass_settings.access_token_bypassed?(other_user)).to be_falsy
      end
    end

    context 'when user is nil' do
      it 'returns false' do
        expect(bypass_settings.access_token_bypassed?(nil)).to be false
      end
    end

    context 'when access token list is empty' do
      let(:bypass_settings_hash) { { access_tokens: [] } }

      it 'returns false' do
        expect(bypass_settings.access_token_bypassed?(user)).to be false
      end
    end

    context 'when access_tokens key is missing' do
      let(:bypass_settings_hash) { {} }

      it 'returns false' do
        expect(bypass_settings.access_token_bypassed?(user)).to be false
      end
    end

    context 'when user has inactive access token' do
      let_it_be(:inactive_token) { create(:personal_access_token, :revoked, user: user) }
      let(:bypass_settings_hash) do
        {
          access_tokens: [{ id: inactive_token.id }]
        }
      end

      it 'returns falsy value' do
        expect(bypass_settings.access_token_bypassed?(user)).to be_falsy
      end
    end

    context 'when user has multiple tokens and one is in bypass list' do
      let_it_be(:another_token) { create(:personal_access_token, user: user) }
      let(:bypass_settings_hash) do
        {
          access_tokens: [{ id: access_token.id }]
        }
      end

      it 'returns truthy value' do
        expect(bypass_settings.access_token_bypassed?(user)).to be_truthy
      end
    end
  end

  describe 'interface parity with Security::ScanResultPolicies::BypassSettings' do
    # The shared Security::ScanResultPolicies::*BypassChecker classes are invoked
    # against ANY policy returned by `Security::Policy.with_bypass_settings`,
    # which today includes dependency-firewall policies. Any interface drift
    # between this class and its scan-result sibling causes NoMethodError in
    # the git-push pre-receive path. Keep the two classes in sync.
    let(:methods_expected) do
      Security::ScanResultPolicies::BypassSettings.instance_methods(false)
    end

    it 'implements every public instance method of the scan-result-policy sibling' do
      described_class_methods = described_class.instance_methods(false)
      missing = methods_expected - described_class_methods
      expect(missing).to be_empty,
        "DF BypassSettings is missing #{missing.inspect}, which shared bypass checkers assume"
    end
  end
end
