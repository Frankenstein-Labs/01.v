# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting branch protection for a branch rule', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:branch_rule) { create(:protected_branch) }
  let_it_be(:project) { branch_rule.project }

  let(:branch_protection_data) do
    graphql_data_at('project', 'branchRules', 'nodes', 1, 'branchProtection')
  end

  let(:variables) { { path: project.full_path } }

  let(:fields) { all_graphql_fields_for('branch_protections'.classify) }

  let(:query) do
    <<~GQL
    query($path: ID!) {
      project(fullPath: $path) {
        branchRules(first: 2) {
          nodes {
            branchProtection {
              #{fields}
            }
          }
        }
      }
    }
    GQL
  end

  context 'when the user does have read_protected_branch abilities' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it 'includes code_owner_approval_required' do
      expect(branch_protection_data['codeOwnerApprovalRequired']).to be_in([true, false])
      expect(branch_protection_data['codeOwnerApprovalRequired']).to eq(branch_rule.code_owner_approval_required)
    end
  end

  context 'when querying member_role on access levels' do
    let(:group) { create(:group) }
    let(:member_role_project) { create(:project, :repository, group: group) }
    let(:member_role) { create(:member_role, :developer, namespace: group) }
    let(:protected_branch_with_role) { create(:protected_branch, project: member_role_project) }

    let(:variables) { { path: member_role_project.full_path } }

    let(:branch_protection_data) do
      nodes = graphql_data_at('project', 'branchRules', 'nodes')
      node = nodes&.find { |n| n.dig('branchProtection', 'mergeAccessLevels', 'nodes')&.any? }
      node&.dig('branchProtection')
    end

    let(:query) do
      <<~GQL
      query($path: ID!) {
        project(fullPath: $path) {
          branchRules(first: 2) {
            nodes {
              branchProtection {
                mergeAccessLevels {
                  nodes {
                    accessLevel
                    accessLevelDescription
                    memberRole {
                      id
                      name
                    }
                  }
                }
                pushAccessLevels {
                  nodes {
                    accessLevel
                    accessLevelDescription
                    memberRole {
                      id
                      name
                    }
                  }
                }
                unprotectAccessLevels {
                  nodes {
                    accessLevel
                    accessLevelDescription
                    memberRole {
                      id
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
      GQL
    end

    before do
      group.add_maintainer(current_user)
      stub_licensed_features(custom_roles: true)
      protected_branch_with_role.merge_access_levels.create!(
        member_role: member_role, access_level: member_role.base_access_level
      )
      protected_branch_with_role.push_access_levels.create!(
        member_role: member_role, access_level: member_role.base_access_level
      )
      protected_branch_with_role.unprotect_access_levels.create!(
        member_role: member_role, access_level: member_role.base_access_level
      )
    end

    context 'when custom_roles_for_protected_branches is enabled' do
      before do
        post_graphql(query, current_user: current_user, variables: variables)
      end

      it 'returns member_role data across all access level types', :aggregate_failures do
        %w[mergeAccessLevels pushAccessLevels unprotectAccessLevels].each do |access_type|
          levels = branch_protection_data.dig(access_type, 'nodes')
          member_role_level = levels.find { |l| l['memberRole'].present? }

          expect(member_role_level).to be_present
          expect(member_role_level.dig('memberRole', 'name')).to eq(member_role.name)
        end
      end

      it 'avoids N+1 queries when querying member_role', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user, variables: variables)
        end

        another_role = create(:member_role, :developer, namespace: group, name: 'Another Role')
        another_branch = create(:protected_branch, project: member_role_project)
        another_branch.merge_access_levels.create!(
          member_role: another_role, access_level: another_role.base_access_level
        )
        another_branch.push_access_levels.create!(
          member_role: another_role, access_level: another_role.base_access_level
        )
        another_branch.unprotect_access_levels.create!(
          member_role: another_role, access_level: another_role.base_access_level
        )

        expect do
          post_graphql(query, current_user: current_user, variables: variables)
        end.not_to exceed_all_query_limit(control)
      end
    end

    context 'when custom_roles_for_protected_branches is disabled' do
      before do
        stub_feature_flags(custom_roles_for_protected_branches: false)
        post_graphql(query, current_user: current_user, variables: variables)
      end

      it 'returns null for member_role across all access level types', :aggregate_failures do
        %w[mergeAccessLevels pushAccessLevels unprotectAccessLevels].each do |access_type|
          levels = branch_protection_data.dig(access_type, 'nodes')
          levels.each do |level|
            expect(level['memberRole']).to be_nil
          end
        end
      end
    end
  end
end
