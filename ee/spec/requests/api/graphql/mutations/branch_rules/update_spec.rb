# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BranchRuleUpdate', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project, freeze: false) { create(:project, :public) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:protected_branch) do
    create(:protected_branch, project: project, default_merge_level: false, default_push_level: false)
  end

  let!(:code_owner_approval_required) { !protected_branch.code_owner_approval_required }
  let!(:allow_force_push) { !protected_branch.allow_force_push }

  let(:current_user) { user }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:global_id) { branch_rule.to_global_id }
  let(:name) { 'new_name' }
  let(:merge_access_levels) { [{ access_level: 0 }] }
  let(:push_access_levels) { [{ access_level: 0 }] }
  let(:mutation) { graphql_mutation(:branch_rule_update, params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_update) }
  let(:params) do
    {
      id: global_id,
      name: name,
      branch_protection: {
        code_owner_approval_required: code_owner_approval_required,
        allow_force_push: allow_force_push,
        merge_access_levels: merge_access_levels,
        push_access_levels: push_access_levels
      }
    }
  end

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: user) }

  context 'when the user can update a branch rules' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(code_owner_approval_required: true)
    end

    it 'updates the branch rule' do
      post_mutation

      expect(protected_branch.reload.name).to eq(name)
      expect(protected_branch.code_owner_approval_required).to eq(code_owner_approval_required)
      expect(protected_branch.allow_force_push).to eq(allow_force_push)

      merge_access_level = an_object_having_attributes(**merge_access_levels.first)
      expect(protected_branch.merge_access_levels).to contain_exactly(merge_access_level)

      push_access_level = an_object_having_attributes(**push_access_levels.first)
      expect(protected_branch.push_access_levels).to contain_exactly(push_access_level)
    end
  end

  context 'with member_role_id' do
    let_it_be(:group) { project.namespace.root_ancestor }
    let_it_be(:member_role) { create(:member_role, namespace: group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:other_member_role) { create(:member_role, namespace: other_group) }

    let(:merge_access_levels) { [{ member_role_id: global_id_of(member_role) }] }
    let(:push_access_levels) { [{ member_role_id: global_id_of(member_role) }] }

    before do
      stub_licensed_features(custom_roles: true, code_owner_approval_required: true)
    end

    it 'adds member role access levels', :aggregate_failures do
      post_mutation

      expect(protected_branch.reload.merge_access_levels).to contain_exactly(
        an_object_having_attributes(member_role_id: member_role.id)
      )
      expect(protected_branch.push_access_levels).to contain_exactly(
        an_object_having_attributes(member_role_id: member_role.id)
      )
    end

    context 'when member_role belongs to a different namespace' do
      let(:merge_access_levels) { [{ member_role_id: global_id_of(other_member_role) }] }

      it 'returns errors in mutation response', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to include(
          'Merge access levels member role must belong to the same root namespace as the project or group'
        )
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_roles_for_protected_branches: false)
      end

      it 'returns errors in mutation response', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to include(
          'Merge access levels member role is not licensed for the root namespace',
          'Push access levels member role is not licensed for the root namespace'
        )
      end
    end

    context 'when custom_roles is not licensed' do
      before do
        stub_licensed_features(custom_roles: false, code_owner_approval_required: true)
      end

      it 'returns errors in mutation response', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to include(
          'Merge access levels member role is not licensed for the root namespace',
          'Push access levels member role is not licensed for the root namespace'
        )
      end
    end

    context 'when an existing member_role access level is not included in the update' do
      let(:new_member_role) { create(:member_role, namespace: group) }
      let(:merge_access_levels) { [{ member_role_id: global_id_of(new_member_role) }] }

      before do
        protected_branch.merge_access_levels.create!(member_role_id: member_role.id)
      end

      it 'replaces the existing member_role access level', :aggregate_failures do
        post_mutation

        expect(protected_branch.reload.merge_access_levels).to contain_exactly(
          an_object_having_attributes(member_role_id: new_member_role.id)
        )
      end
    end
  end

  context 'with blocking scan result policy' do
    let(:branch_name) { branch_rule.name }
    let(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    include_context 'with approval security policy blocking protected branches'

    it 'returns a clear policy-violation message instead of a generic error', :aggregate_failures do
      post_mutation

      expect(graphql_errors).to be_blank
      expect(mutation_response['errors']).to include(a_string_matching(/prevents branch modification/))
      expect(mutation_response['branchRule']).to be_nil
    end
  end

  # Regression: issue #602530. A genuine push-access change under a
  # prevent_pushing_and_force_pushing policy must still be blocked, but with a
  # clear message rather than a generic "resource not available" error.
  context 'with a prevent_pushing_and_force_pushing policy' do
    let(:branch_name) { branch_rule.name }
    let(:name) { protected_branch.name }
    let(:allow_force_push) { protected_branch.allow_force_push }
    let(:push_access_levels) { [{ access_level: Gitlab::Access::DEVELOPER }] }

    let(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    include_context 'with approval security policy preventing force pushing'

    it 'blocks a genuine push-access change with a clear policy-violation message', :aggregate_failures do
      post_mutation

      expect(graphql_errors).to be_blank
      expect(mutation_response['errors'])
        .to include(a_string_matching(/blocked by a security policy that prevents pushing/))
      expect(mutation_response['branchRule']).to be_nil
    end

    # The core regression: editing only merge access (with push access levels
    # omitted, as the frontend now sends) must succeed and leave the stored
    # push access levels untouched, rather than being falsely blocked.
    context 'when only merge access changes and push access levels are omitted' do
      let(:merge_access_levels) { [{ access_level: Gitlab::Access::DEVELOPER }] }
      let(:params) do
        {
          id: global_id,
          name: name,
          branch_protection: {
            merge_access_levels: merge_access_levels
          }
        }
      end

      it 'updates the branch rule without blocking and leaves push access untouched', :aggregate_failures do
        post_mutation

        expect(graphql_errors).to be_blank
        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['branchRule']).to be_present
        expect(protected_branch.reload.push_access_levels).to be_empty
        expect(protected_branch.merge_access_levels.map(&:access_level))
          .to contain_exactly(Gitlab::Access::DEVELOPER)
      end
    end
  end
end
