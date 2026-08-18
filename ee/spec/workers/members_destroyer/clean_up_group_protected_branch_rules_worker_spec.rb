# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MembersDestroyer::CleanUpGroupProtectedBranchRulesWorker, type: :worker, feature_category: :groups_and_projects do
  include NonExistingRecordsHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:sub_project) { create(:project, group: sub_group) }

  let(:group_id) { group.id }
  let(:user_id) { user.id }

  subject do
    described_class.new.perform(group_id, user_id)
  end

  describe '#perform' do
    context 'when member has protected branch rules in projects or sub-projects' do
      let!(:protected_branches) do
        list = create_list(:protected_branch, 2, project: project)
        list << create(:protected_branch, project: sub_project) # 3 protected branches are created
      end

      it 'deletes all associated merge_access_levels' do
        create_merge_access_levels

        expect { subject }
          .to change { ProtectedBranch::MergeAccessLevel.count }.by(-3)
      end

      it 'deletes all associated push_access_levels' do
        create_push_access_levels

        expect { subject }
          .to change { ProtectedBranch::PushAccessLevel.count }.by(-3)
      end

      context 'when user is still a project member' do
        let!(:project_membership) { project.add_developer(user) }

        it 'does not delete associated merge_access_levels in the projects' do
          create_merge_access_levels

          expect { subject }
            .to change { ProtectedBranch::MergeAccessLevel.count }.by(-1)
          # -1 because sub_project access should still be deleted
        end

        it 'does not delete associated the push_access_levels in the projects' do
          create_push_access_levels

          expect { subject }
            .to change { ProtectedBranch::PushAccessLevel.count }.by(-1)
        end
      end

      describe 'checks if resource exists' do
        shared_examples 'when a resource does not exist' do
          it 'does not run #destroy_protected_branches_access' do
            worker_instance = described_class.new

            expect(worker_instance).not_to receive(:destroy_protected_branches_access)

            worker_instance.perform(group_id, user_id)
          end
        end

        context 'when group_id does not exist' do
          let(:group_id) { non_existing_record_id }

          it_behaves_like 'when a resource does not exist'
        end

        context 'when user_id does not exist' do
          let(:user_id) { non_existing_record_id }

          it_behaves_like 'when a resource does not exist'
        end
      end

      def create_merge_access_levels
        protected_branches.each do |protected_branch|
          access_level = build(:protected_branch_merge_access_level, protected_branch: protected_branch, user: user)
          save_access_level(access_level)
        end
      end

      def create_push_access_levels
        protected_branches.each do |protected_branch|
          access_level = build(:protected_branch_push_access_level, protected_branch: protected_branch, user: user)
          save_access_level(access_level)
        end
      end

      def save_access_level(access_level)
        access_level.save!(validate: false) # Need to be able to create without memberships
        access_level
      end
    end
  end
end
