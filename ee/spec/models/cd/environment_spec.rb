# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Environment, feature_category: :continuous_delivery do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to have_many(:environment_driver_bindings) }
    it { is_expected.to have_many(:rollout_environments) }
    it { is_expected.to have_many(:service_environment_healths) }
  end

  describe 'validations' do
    subject { create(:cd_environment) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id) }
    it { is_expected.to validate_presence_of(:tier) }
    it { is_expected.to define_enum_for(:tier).with_values(development: 0, qa: 1, staging: 2, production: 3) }

    describe 'name format' do
      it { is_expected.to allow_value('my-env').for(:name) }
      it { is_expected.to allow_value('my_env').for(:name) }
      it { is_expected.to allow_value('MyEnv').for(:name) }
      it { is_expected.to allow_value('env1').for(:name) }
      it { is_expected.to allow_value('1env').for(:name) }
      it { is_expected.not_to allow_value('-env').for(:name) }
      it { is_expected.not_to allow_value('env-').for(:name) }
      it { is_expected.not_to allow_value('my env').for(:name) }
      it { is_expected.not_to allow_value('env/name').for(:name) }
      it { is_expected.not_to allow_value('env.name').for(:name) }
      it { is_expected.not_to allow_value('env!').for(:name) }
    end

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }

    describe 'sharding key' do
      it 'is invalid without an organization' do
        env = build(:cd_environment, organization: nil)

        expect(env).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_organization' do
      it 'returns environments belonging to the given organization' do
        env = create(:cd_environment)
        create(:cd_environment)

        expect(described_class.for_organization(env.organization_id)).to contain_exactly(env)
      end
    end

    describe '.in_organization' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:org_environment) { create(:cd_environment, organization: organization) }
      let_it_be(:other_org_environment) { create(:cd_environment, organization: other_organization) }

      it 'returns environments belonging to the organization' do
        expect(described_class.in_organization(organization)).to contain_exactly(org_environment)
      end
    end

    describe '.order_by_name_asc' do
      it 'returns environments ordered by name ascending' do
        env_b = create(:cd_environment, name: 'beta')
        env_a = create(:cd_environment, name: 'alpha')

        expect(described_class.order_by_name_asc).to eq([env_a, env_b])
      end
    end

    describe '.with_tier' do
      let_it_be(:production_env) { create(:cd_environment, :production) }
      let_it_be(:staging_env) { create(:cd_environment, :staging) }

      it 'returns environments matching the given tier' do
        expect(described_class.with_tier(:production)).to contain_exactly(production_env)
      end
    end

    describe '.search' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:prod) do
        create(:cd_environment, organization: organization, name: 'prod-eu-west-1',
          description: 'EU production cluster')
      end

      let_it_be(:staging) do
        create(:cd_environment, organization: organization, name: 'staging-us-east-1', description: 'US staging')
      end

      it 'matches on name' do
        expect(described_class.in_organization(organization).search('prod')).to contain_exactly(prod)
      end

      it 'matches on description' do
        expect(described_class.in_organization(organization).search('cluster')).to contain_exactly(prod)
      end
    end
  end
end
