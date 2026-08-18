# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Access, feature_category: :permissions do
  let_it_be_with_reload(:member) { create(:group_member, :developer) }
  let_it_be(:member_role) { create(:member_role, :developer, name: 'IM') }
  let_it_be(:minimal_access_member) { create(:group_member, :minimal_access) }

  describe '.human_access_with_none' do
    it 'returns correct name for default role' do
      expect(described_class.human_access_with_none(::Gitlab::Access::DEVELOPER)).to eq('Developer')
    end

    it 'return correct name for minimal role' do
      expect(described_class.human_access_with_none(::Gitlab::Access::MINIMAL_ACCESS)).to eq('Minimal Access')
    end

    it 'return correct name for none role' do
      expect(described_class.human_access_with_none(::Gitlab::Access::NO_ACCESS)).to eq('None')
    end

    it 'returns correct name for custom role' do
      member.update!(member_role: member_role)

      expect(described_class.human_access_with_none(Gitlab::Access::DEVELOPER, member_role)).to eq('IM')
    end
  end

  describe '#human_access' do
    it 'returns correct name for default role' do
      expect(member.human_access).to eq('Developer')
    end

    it 'returns correct name for custom role' do
      member.update!(member_role: member_role)

      expect(member.human_access).to eq('IM')
    end
  end

  describe '#human_access_with_none' do
    it 'returns correct name for default role' do
      expect(member.human_access_with_none).to eq('Developer')
    end

    it 'return correct name for minimal role' do
      member.access_level = ::Gitlab::Access::MINIMAL_ACCESS

      expect(member.human_access_with_none).to eq('Minimal Access')
    end

    it 'return correct name for none role' do
      member.access_level = ::Gitlab::Access::NO_ACCESS

      expect(member.human_access_with_none).to eq('None')
    end

    it 'returns correct name for custom role' do
      member.update!(member_role: member_role)

      expect(member.human_access_with_none).to eq('IM')
    end
  end

  describe '#human_access_labeled' do
    it 'returns correct label for default role' do
      expect(member.human_access_labeled).to eq('Default role: Developer')
    end

    it 'returns correct label for custom role' do
      member.update!(member_role: member_role)

      expect(member.human_access_labeled).to eq('Custom role: IM')
    end
  end

  describe '#role_description' do
    it 'returns the correct description of the minimal access role' do
      description = described_class.option_descriptions[described_class::MINIMAL_ACCESS]

      expect(minimal_access_member.role_description).to eq(description)
    end
  end

  describe '.options_with_minimal_access' do
    it 'returns the hash of roles with Owner' do
      expected_result = {
        "Guest" => 10, "Planner" => 15, "Reporter" => 20, "Security Manager" => 25,
        "Developer" => 30, "Maintainer" => 40, 'Owner' => 50,
        "Minimal Access" => 5
      }

      expect(described_class.options_with_minimal_access).to eq(expected_result)
    end
  end

  describe '.options_for_custom_roles' do
    it 'returns the hash of roles without Owner' do
      expected_result = {
        "Guest" => 10, "Planner" => 15, "Reporter" => 20, "Security Manager" => 25,
        "Developer" => 30, "Maintainer" => 40, "Minimal Access" => 5
      }

      expect(described_class.options_for_custom_roles).to eq(expected_result)
    end
  end
end
