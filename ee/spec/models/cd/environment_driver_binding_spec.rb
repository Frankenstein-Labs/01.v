# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::EnvironmentDriverBinding, feature_category: :continuous_delivery do
  let_it_be(:environment) { create(:cd_environment) }

  describe 'factory' do
    it 'creates a valid driver binding using factory defaults' do
      expect(create(:cd_environment_driver_binding)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:environment).required }
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to have_many(:rollout_environments) }
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'orders by version descending' do
        environment = create(:cd_environment)
        older = create(:cd_environment_driver_binding, environment: environment)
        newer = create(:cd_environment_driver_binding, environment: environment)

        expect(described_class.ordered).to eq([newer, older])
      end
    end
  end

  describe '#assign_next_version' do
    it 'assigns version 1 to the first binding on an environment' do
      binding = create(:cd_environment_driver_binding, environment: environment)

      expect(binding.version).to eq(1)
    end

    it 'assigns the next version to a subsequent binding on the same environment' do
      create(:cd_environment_driver_binding, environment: environment)
      second = create(:cd_environment_driver_binding, environment: environment)

      expect(second.version).to eq(2)
    end

    it 'starts each environment at version 1 independently' do
      other_environment = create(:cd_environment)
      create(:cd_environment_driver_binding, environment: environment)

      binding = create(:cd_environment_driver_binding, environment: other_environment)

      expect(binding.version).to eq(1)
    end
  end

  describe 'validations' do
    subject { build(:cd_environment_driver_binding, environment: environment) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:driver_ref) }
    it { is_expected.to validate_length_of(:driver_ref).is_at_most(255) }

    it 'validates presence of version' do
      binding = build(:cd_environment_driver_binding, environment: environment)
      allow(binding).to receive(:assign_next_version)
      binding.version = nil

      expect(binding).not_to be_valid
      expect(binding.errors[:version]).to include("can't be blank")
    end

    it 'rejects a duplicate version for the same environment' do
      existing = create(:cd_environment_driver_binding, environment: environment)

      duplicate = build(:cd_environment_driver_binding, environment: environment)
      allow(duplicate).to receive(:assign_next_version)
      duplicate.version = existing.version

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:version]).to be_present
    end

    it 'allows the same version on a different environment' do
      existing = create(:cd_environment_driver_binding, environment: environment)

      other = build(:cd_environment_driver_binding, environment: create(:cd_environment))
      allow(other).to receive(:assign_next_version)
      other.version = existing.version

      expect(other).to be_valid
    end

    it 'rejects a non-object driver_config' do
      binding = build(:cd_environment_driver_binding, environment: environment, driver_config: [])

      expect(binding).not_to be_valid
    end

    it 'accepts the driver_config the registration form sends' do
      binding = build(:cd_environment_driver_binding, environment: environment,
        driver_config: { 'cluster_agent_id' => '1' })

      expect(binding).to be_valid
    end

    it 'rejects a blank cluster_agent_id' do
      binding = build(:cd_environment_driver_binding, environment: environment,
        driver_config: { 'cluster_agent_id' => '' })

      expect(binding).not_to be_valid
    end

    # The Argo Rollouts environment schema sets additionalProperties: false, so a config may
    # carry only cluster_agent_id. cluster_agent_name was dropped in v0.4.0, and nothing here
    # replaces it: the agent's display name is looked up from the ID by whoever renders it.
    it 'rejects a driver_config carrying a key the driver schema does not declare' do
      binding = build(:cd_environment_driver_binding, environment: environment,
        driver_config: { 'cluster_agent_id' => '1', 'cluster_agent_name' => 'production-agent' })

      expect(binding).not_to be_valid
      expect(binding.errors[:driver_config]).to include(a_string_matching(/cluster_agent_name/))
    end
  end

  describe 'sharding key' do
    subject { build(:cd_environment_driver_binding, environment: environment) }

    it { is_expected.to populate_sharding_key(:organization_id).with(environment.organization_id) }
  end

  describe 'append-only' do
    it 'prevents modification of a persisted record' do
      binding = create(:cd_environment_driver_binding, environment: environment)

      # driver_config must stay schema-valid so the update reaches the append-only guard instead of
      # tripping the driver_config_matches_driver_schema validation first (validations run before callbacks).
      expect { binding.update!(driver_config: { 'cluster_agent_id' => '2' }) }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
