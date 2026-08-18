# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Setting, :aggregate_failures, feature_category: :virtual_registry do
  describe 'validations' do
    it { is_expected.to allow_value(true, false).for(:enabled) }
    it { is_expected.not_to allow_value(nil).for(:enabled) }
    it { is_expected.to validate_presence_of(:group) }

    context 'when validating root group' do
      let(:root_group) { create(:group) }
      let(:subgroup) { create(:group, parent: root_group) }

      it 'allows root groups' do
        setting = build(:virtual_registries_setting, group: root_group)

        expect(setting).to be_valid
      end

      it 'rejects subgroups' do
        setting = build(:virtual_registries_setting, group: subgroup)

        expect(setting).not_to be_valid
        expect(setting.errors[:group]).to include('must be a top level Group')
      end
    end
  end

  describe '.find_for_group' do
    let_it_be(:group) { create(:group) }

    subject { described_class.find_for_group(group) }

    context 'when a setting exists for the group' do
      let_it_be(:expected_setting) { create(:virtual_registries_setting, group: group) }
      let_it_be(:other_setting) { create(:virtual_registries_setting) }

      it { is_expected.to eq(expected_setting) }
    end

    context 'when a setting does not exist for the group' do
      it { is_expected.to be_a_new(described_class) }
      it { is_expected.to have_attributes(group: group, enabled: true) }
    end
  end

  describe '.enabled_for_group?', :request_store do
    let_it_be(:group) { create(:group) }

    it 'caches the result within the same request' do
      allow(described_class).to receive(:find_for_group).and_call_original

      2.times do
        described_class.enabled_for_group?(group)
      end

      expect(described_class).to have_received(:find_for_group).with(group).once
    end
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      setting = build(:virtual_registries_setting)
      policy = DeclarativePolicy.policy_for(build(:user), setting)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
