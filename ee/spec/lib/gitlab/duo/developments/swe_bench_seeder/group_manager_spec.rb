# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles -- Using doubles for simplicity in tests

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::GroupManager, feature_category: :duo_chat do
  let(:user) { double(User) }
  let_it_be(:organization, freeze: true) { create(:organization) }

  describe '.find_or_create_parent_group' do
    let(:group_path) { 'gitlab-duo' }

    context 'when no organizations exists at all' do
      before do
        Organizations::Organization.delete_all
      end

      it 'raises an error' do
        expect { described_class.find_or_create_parent_group(user) }.to raise_error(/No seeded organization/)
      end
    end

    context 'when parent group already exists' do
      let(:existing_group) { double('Group', full_path: group_path) }

      before do
        allow(Group).to receive(:find_by_full_path).with(group_path).and_return(existing_group)
      end

      it 'returns the existing group' do
        result = described_class.find_or_create_parent_group(user)

        expect(result).to eq(existing_group)
      end

      it 'prints message about finding existing group' do
        expect { described_class.find_or_create_parent_group(user) }.to output(/Found existing parent group/).to_stdout
      end
    end

    context 'when parent group does not exist' do
      let(:created_group) { double('Group', full_path: group_path) }

      before do
        allow(Group).to receive(:find_by_full_path).with(group_path).and_return(nil)
        response = double(error?: false)
        allow(response).to receive(:[]).with(:group).and_return(created_group)
        allow_next_instance_of(Groups::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(response)
        end
      end

      it 'creates a new parent group' do
        result = described_class.find_or_create_parent_group(user)

        expect(result).to be_truthy
      end

      it 'prints message about creating group' do
        expect { described_class.find_or_create_parent_group(user) }.to output(/Created parent group/).to_stdout
      end
    end

    context 'when group creation fails' do
      before do
        allow(Group).to receive(:find_by_full_path).with(group_path).and_return(nil)
        response = double(error?: true, errors: double(full_messages: ['Error message']))
        allow_next_instance_of(Groups::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(response)
        end
      end

      it 'raises an error' do
        expect { described_class.find_or_create_parent_group(user) }.to raise_error(/Failed to create parent group/)
      end
    end
  end

  describe '.find_or_create_subgroup' do
    let(:parent_group) do
      double('Group', id: 1, organization: organization, visibility_level: Gitlab::VisibilityLevel::PUBLIC)
    end

    let(:subgroup_path) { 'gitlab-duo/swe-bench-seeded-data' }

    context 'when subgroup already exists' do
      let(:existing_subgroup) { double('Group', full_path: subgroup_path) }

      before do
        allow(Group).to receive(:find_by_full_path).with(subgroup_path).and_return(existing_subgroup)
      end

      it 'returns the existing subgroup' do
        result = described_class.find_or_create_subgroup(parent_group, user)

        expect(result).to eq(existing_subgroup)
      end

      it 'prints message about finding existing subgroup' do
        expect do
          described_class.find_or_create_subgroup(parent_group, user)
        end.to output(/Found existing subgroup/).to_stdout
      end
    end

    context 'when subgroup does not exist' do
      let(:created_subgroup) { double('Group', full_path: subgroup_path) }

      before do
        allow(Group).to receive(:find_by_full_path).with(subgroup_path).and_return(nil)
        response = double(error?: false)
        allow(response).to receive(:[]).with(:group).and_return(created_subgroup)
        allow_next_instance_of(Groups::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(response)
        end
      end

      it 'creates a new subgroup' do
        result = described_class.find_or_create_subgroup(parent_group, user)

        expect(result).to be_truthy
      end

      it 'prints message about creating subgroup' do
        expect { described_class.find_or_create_subgroup(parent_group, user) }.to output(/Created subgroup/).to_stdout
      end
    end

    context 'when subgroup creation fails' do
      before do
        allow(Group).to receive(:find_by_full_path).with(subgroup_path).and_return(nil)
        response = double(error?: true, errors: double(full_messages: ['Error message']))
        allow_next_instance_of(Groups::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(response)
        end
      end

      it 'raises an error' do
        expect do
          described_class.find_or_create_subgroup(parent_group, user)
        end.to raise_error(/Failed to create subgroup/)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
