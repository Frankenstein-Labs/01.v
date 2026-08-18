# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassSettings, feature_category: :security_policy_management do
  let(:bypass_settings) do
    {
      access_tokens: [
        { id: 1 },
        { id: 2 }
      ],
      service_accounts: [
        { id: 10 },
        { id: 20 }
      ]
    }
  end

  subject(:bypass_settings_instance) { described_class.new(bypass_settings) }

  describe '#access_token_ids' do
    it 'returns the ids of access tokens' do
      expect(bypass_settings_instance.access_token_ids).to match_array([1, 2])
    end

    context 'when access_tokens is nil' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.access_token_ids).to be_empty
      end
    end
  end

  describe '#service_account_ids' do
    it 'returns the ids of service accounts' do
      expect(bypass_settings_instance.service_account_ids).to match_array([10, 20])
    end

    context 'when service_accounts is nil' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.service_account_ids).to be_empty
      end
    end
  end

  describe '#branches' do
    context 'when branches are present' do
      let(:bypass_settings) do
        {
          branches: [{ target: { name: 'main' } }, { source: { name: 'develop' } }]
        }
      end

      it 'returns the branches array' do
        expect(bypass_settings_instance.branches).to match_array([
          { target: { name: 'main' } }, { source: { name: 'develop' } }
        ])
      end
    end

    context 'when branches are nil or missing' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.branches).to be_empty
      end
    end
  end

  describe '#user_ids' do
    context 'when users are present' do
      let(:bypass_settings) { { users: [{ id: 100 }, { id: 200 }] } }

      it 'returns the ids of users' do
        expect(bypass_settings_instance.user_ids).to match_array([100, 200])
      end
    end

    context 'when users is nil or missing' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.user_ids).to be_empty
      end
    end
  end

  describe '#group_ids' do
    context 'when groups are present' do
      let(:bypass_settings) { { groups: [{ id: 300 }, { id: 400 }] } }

      it 'returns the ids of groups' do
        expect(bypass_settings_instance.group_ids).to match_array([300, 400])
      end
    end

    context 'when groups is nil or missing' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.group_ids).to be_empty
      end
    end
  end

  describe '#default_roles' do
    context 'when roles are present' do
      let(:bypass_settings) { { roles: %w[maintainer developer developer] } }

      it 'returns unique roles as an array' do
        expect(bypass_settings_instance.default_roles).to match_array(%w[maintainer developer])
      end
    end

    context 'when roles is nil or missing' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.default_roles).to eq([])
      end
    end
  end

  describe '#custom_role_ids' do
    context 'when custom_roles are present' do
      let(:bypass_settings) { { custom_roles: [{ id: 500 }, { id: 600 }] } }

      it 'returns the ids of custom roles' do
        expect(bypass_settings_instance.custom_role_ids).to match_array([500, 600])
      end
    end

    context 'when custom_roles is nil or missing' do
      let(:bypass_settings) { {} }

      it 'returns empty array' do
        expect(bypass_settings_instance.custom_role_ids).to be_empty
      end
    end
  end

  describe '#users_and_groups_empty?' do
    context 'when all collections are empty' do
      let(:bypass_settings) { {} }

      it 'returns true' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be true
      end
    end

    context 'when user_ids is not empty' do
      let(:bypass_settings) { { users: [{ id: 100 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when group_ids is not empty' do
      let(:bypass_settings) { { groups: [{ id: 200 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when default_roles is not empty' do
      let(:bypass_settings) { { roles: ['maintainer'] } }

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when custom_role_ids is not empty' do
      let(:bypass_settings) { { custom_roles: [{ id: 300 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when multiple collections have data' do
      let(:bypass_settings) do
        {
          users: [{ id: 100 }],
          groups: [{ id: 200 }],
          roles: ['maintainer'],
          custom_roles: [{ id: 300 }]
        }
      end

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when some collections are empty and others have data' do
      let(:bypass_settings) do
        {
          users: [],
          groups: [{ id: 200 }],
          roles: [],
          custom_roles: []
        }
      end

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be false
      end
    end

    context 'when bypass_settings is nil' do
      subject(:bypass_settings_instance) { described_class.new(nil) }

      it 'returns true' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be true
      end
    end
  end

  describe '#bypass_actors_empty?' do
    context 'when all collections are empty' do
      let(:bypass_settings) { {} }

      it 'returns true' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be true
      end
    end

    context 'when only access_token_ids is not empty' do
      let(:bypass_settings) { { access_tokens: [{ id: 1 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when only service_account_ids is not empty' do
      let(:bypass_settings) { { service_accounts: [{ id: 10 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when only user_ids is not empty' do
      let(:bypass_settings) { { users: [{ id: 100 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when only group_ids is not empty' do
      let(:bypass_settings) { { groups: [{ id: 200 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when only default_roles is not empty' do
      let(:bypass_settings) { { roles: ['maintainer'] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when only custom_role_ids is not empty' do
      let(:bypass_settings) { { custom_roles: [{ id: 300 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when users_and_groups_empty but access_tokens present' do
      let(:bypass_settings) { { access_tokens: [{ id: 1 }] } }

      it 'returns false' do
        expect(bypass_settings_instance.users_and_groups_empty?).to be true
        expect(bypass_settings_instance.bypass_actors_empty?).to be false
      end
    end

    context 'when bypass_settings is nil' do
      subject(:bypass_settings_instance) { described_class.new(nil) }

      it 'returns true' do
        expect(bypass_settings_instance.bypass_actors_empty?).to be true
      end
    end
  end
end
