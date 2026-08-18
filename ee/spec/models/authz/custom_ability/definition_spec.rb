# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::CustomAbility::Definition, feature_category: :permissions do
  subject(:definition) { described_class.new(ability_name) }

  let(:ability_name) { :admin_group_member }
  let(:project_ability) { true }
  let(:group_ability) { true }
  let(:admin_ability) { true }
  let(:definition_sample) do
    {
      admin_group_member: {
        name: 'admin_group_member',
        group_ability: group_ability,
        project_ability: project_ability
      }
    }
  end

  before do
    allow(Gitlab::CustomRoles::Definition).to receive(:all).and_return(definition_sample)
  end

  describe '#name' do
    subject { definition.name }

    it { is_expected.to eq(ability_name) }

    context 'when ability name is a string' do
      let(:ability_name) { 'admin_group_member' }

      it { is_expected.to eq(:admin_group_member) }
    end

    context 'when ability does not exist' do
      let(:ability_name) { :unknown }

      it { is_expected.to be_nil }
    end
  end

  describe '#exists?' do
    subject { definition.exists? }

    it { is_expected.to be_truthy }

    context 'when ability does not exist' do
      let(:ability_name) { :unknown }

      it { is_expected.to be_falsey }
    end
  end

  describe '#group_ability_enabled?' do
    subject { definition.group_ability_enabled? }

    it { is_expected.to be_truthy }

    context 'when group ability is restricted' do
      let(:group_ability) { false }

      it { is_expected.to be_falsey }
    end

    context 'when ability does not exist' do
      let(:ability_name) { :unknown }

      it { is_expected.to be_falsey }
    end
  end

  describe '#project_ability_enabled?' do
    subject { definition.project_ability_enabled? }

    it { is_expected.to be_truthy }

    context 'when project ability is restricted' do
      let(:project_ability) { false }

      it { is_expected.to be_falsey }
    end

    context 'when ability does not exist' do
      let(:ability_name) { :unknown }

      it { is_expected.to be_falsey }
    end
  end

  describe '#admin_ability_enabled?' do
    let(:group_ability) { false }
    let(:project_ability) { false }

    subject { definition.admin_ability_enabled? }

    it { is_expected.to be_truthy }

    context 'when it is a group ability' do
      let(:group_ability) { true }

      it { is_expected.to be_falsey }
    end

    context 'when it is a project ability' do
      let(:project_ability) { true }

      it { is_expected.to be_falsey }
    end

    context 'when ability does not exist' do
      let(:ability_name) { :unknown }

      it { is_expected.to be_falsey }
    end
  end

  describe '#project_permissions' do
    subject { definition.project_permissions }

    context 'when project_permissions are defined' do
      let(:ability_name) { :admin_web_hook }
      let(:project_ability) { true }
      let(:definition_sample) do
        {
          admin_web_hook: {
            name: 'admin_web_hook',
            group_ability: group_ability,
            project_ability: project_ability,
            project_permissions: %w[admin_web_hook read_web_hook]
          }
        }
      end

      it { is_expected.to match_array([:admin_web_hook, :read_web_hook]) }
    end

    context 'when project_permissions are not defined' do
      it { is_expected.to eq([]) }
    end
  end

  describe '#group_permissions' do
    subject { definition.group_permissions }

    context 'when group_permissions are defined' do
      let(:definition_sample) do
        {
          admin_group_member: {
            name: 'admin_group_member',
            group_ability: group_ability,
            project_ability: project_ability,
            group_permissions: %w[admin_group_member destroy_group_member read_billable_member]
          }
        }
      end

      it { is_expected.to match_array([:admin_group_member, :destroy_group_member, :read_billable_member]) }
    end

    context 'when group_permissions are not defined' do
      it { is_expected.to eq([]) }
    end
  end
end
