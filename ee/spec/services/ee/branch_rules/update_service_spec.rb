# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::UpdateService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:params) { { name: 'test' } }

  describe '#execute' do
    subject(:execute) { described_class.new(branch_rule, user: user, params: params).execute }

    before do
      allow(Ability).to receive(:allowed?).and_return(true)
      stub_licensed_features(code_owner_approval_required: true)
    end

    context 'when branch rule is a Projects::BranchRule' do
      let_it_be(:code_owner_approval_required) { true }
      let_it_be(:developer) { create(:user, developer_of: project) }
      let_it_be(:developers_group) { create(:project_group_link, project: project).group }
      let_it_be_with_reload(:protected_branch) do
        create(
          :protected_branch,
          project: project,
          code_owner_approval_required: !code_owner_approval_required,
          default_merge_level: false,
          default_push_level: false
        )
      end

      let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
      let(:push_access_levels) { [{ user_id: developer.id }, { group_id: developers_group.id }] }
      let(:merge_access_levels) { [{ user_id: developer.id }, { group_id: developers_group.id }] }
      let(:params) do
        {
          branch_protection: {
            code_owner_approval_required: code_owner_approval_required,
            push_access_levels: push_access_levels,
            merge_access_levels: merge_access_levels
          }
        }
      end

      it 'accepts params for EE only settings', :aggregate_failures do
        expect { execute }
          .to change { protected_branch.code_owner_approval_required }.to(code_owner_approval_required)
          .and change { protected_branch.merge_access_levels.count }.by(2)
          .and change { protected_branch.push_access_levels.count }.by(2)

        expect(execute).to be_success
        expect(protected_branch.push_access_levels.first.user_id).to eq(developer.id)
        expect(protected_branch.push_access_levels.second.group_id).to eq(developers_group.id)
        expect(protected_branch.merge_access_levels.first.user_id).to eq(developer.id)
        expect(protected_branch.merge_access_levels.second.group_id).to eq(developers_group.id)
      end

      context 'when code_owner_approval_required is null' do
        let(:code_owner_approval_required) { nil }

        # TODO: We should be validating
        # ProtectedBranch#code_owner_approval_required is not null instead of
        # relying on db constraints
        it 'raises a not null violation error' do
          expect { execute }.to raise_error(ActiveRecord::NotNullViolation)
        end
      end

      context 'with member_role_id' do
        let_it_be(:group) { project.namespace.root_ancestor }
        let_it_be(:member_role) { create(:member_role, namespace: group) }
        let(:push_access_levels) { [{ member_role_id: member_role.id }] }
        let(:merge_access_levels) { [{ member_role_id: member_role.id }] }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'accepts member_role_id and persists it', :aggregate_failures do
          expect { execute }
            .to change { protected_branch.merge_access_levels.count }.by(1)
            .and change { protected_branch.push_access_levels.count }.by(1)

          expect(execute).to be_success
          expect(protected_branch.push_access_levels.first.member_role_id).to eq(member_role.id)
          expect(protected_branch.merge_access_levels.first.member_role_id).to eq(member_role.id)
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
          end

          it 'returns an error response', :aggregate_failures do
            response = execute
            expect(response).to be_error
            expect(response[:message]).to include(
              'Merge access levels member role is not licensed for the root namespace',
              'Push access levels member role is not licensed for the root namespace'
            )
          end
        end

        context 'when custom_roles is not licensed' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'returns an error response', :aggregate_failures do
            response = execute
            expect(response).to be_error
            expect(response[:message]).to include(
              'Merge access levels member role is not licensed for the root namespace',
              'Push access levels member role is not licensed for the root namespace'
            )
          end
        end
      end

      context 'when invalid access_levels are passed' do
        let(:push_access_levels) { [{ user_id: 0 }, { group_id: 0 }] }
        let(:merge_access_levels) { [{ user_id: 0 }, { group_id: 0 }] }

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to match_array([
            "Merge access levels user can't be blank",
            "Merge access levels group can't be blank",
            "Push access levels user can't be blank",
            "Push access levels group can't be blank"
          ])
        end
      end

      context 'when invalid member_role_id is passed' do
        let(:push_access_levels) { [{ member_role_id: 0 }] }
        let(:merge_access_levels) { [{ member_role_id: 0 }] }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to match_array([
            "Merge access levels member role can't be blank",
            "Push access levels member role can't be blank"
          ])
        end
      end

      context 'when name and squash options are not compatible' do
        let(:params) do
          {
            name: '*'
          }
        end

        context 'and there is an existing squash option' do
          let!(:squash_option) do
            create(
              :branch_rule_squash_option,
              :default_on,
              project: protected_branch.project,
              protected_branch: protected_branch)
          end

          it 'returns an error response' do
            response = execute
            expect(response).to be_error
            expect(response[:message]).to match_array([
              'Squash option cannot be used with wildcard branch rules. Use an exact branch name.'
            ])
          end
        end
      end
    end

    context 'when branch_rule is a Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { Projects::AllProtectedBranchesRule.new(project) }

      it 'returns an error response' do
        response = execute
        expect(response).to be_error
        expect(response[:message]).to eq('All protected branches rules cannot be updated.')
      end
    end
  end
end
