# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting list of branch rules for a project', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project, freeze: false) { create(:project, :repository, :public, :in_group) }
  let_it_be(:project_maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:group_maintainer) { create(:user, maintainer_of: [project, project.group]) }

  let(:branch_rules_data) { graphql_data_at('project', 'branchRules', 'nodes') }
  let(:variables) { { path: project.full_path, buildMissing: build_missing } }
  let(:build_missing) { false }
  let(:fields) { all_graphql_fields_for('BranchRule') }
  let(:query) do
    <<~GQL
    query($path: ID!, $n: Int, $cursor: String, $buildMissing: Boolean) {
      project(fullPath: $path) {
        branchRules(first: $n, after: $cursor, buildMissing: $buildMissing) {
          nodes {
            #{fields}
          }
        }
      }
    }
    GQL
  end

  context 'when the user does have read_protected_branch abilities for the project' do
    let(:current_user) { project_maintainer }

    describe 'queries' do
      include_context 'when user tracking is disabled'

      let(:query) do
        <<~GQL
        query($path: ID!) {
          project(fullPath: $path) {
            branchRules {
              nodes {
                matchingBranchesCount
                squashOption{
                  option
                }
                externalStatusChecks{
                  nodes{
                    name
                  }
                }
              }
            }
          }
        }
        GQL
      end

      before do
        create(:protected_branch, project: project)
      end

      it 'avoids N+1 queries', :use_sql_query_cache, :aggregate_failures do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user, variables: variables)
        end

        # Verify the response includes the field
        expect_n_matching_branches_count_fields(2)

        create(:protected_branch, project: project)
        create(:protected_branch, name: '*', project: project)
        create(:protected_branch, project: nil, group: project.group)

        expect do
          post_graphql(query, current_user: current_user, variables: variables)
        end.not_to exceed_all_query_limit(control)

        expect_n_matching_branches_count_fields(5)
      end

      def expect_n_matching_branches_count_fields(count)
        branch_rule_nodes = graphql_data_at('project', 'branchRules', 'nodes')
        expect(branch_rule_nodes.count).to eq(count)
        branch_rule_nodes.each do |node|
          expect(node['matchingBranchesCount']).to be_present
        end
      end
    end

    describe 'response' do
      before do
        post_graphql(query, current_user: current_user, variables: variables)
      end

      let(:all_branches_rule) { Projects::AllBranchesRule.new(project) }
      let(:all_protected_branches_rule) { Projects::AllProtectedBranchesRule.new(project) }

      # branchRules are returned in alphabetical order
      let(:all_branches_rule_data) { branch_rules_data.first }
      let(:all_protected_branches_rule_data) { branch_rules_data.second }

      context 'when custom rules are persisted' do
        let_it_be(:all_branches_external_status_check) do
          create(:external_status_check, project: project)
        end

        let_it_be(:all_branches_approval_rule) do
          create(:approval_project_rule, project: project)
        end

        let_it_be(:all_protected_branches_approval_rule) do
          create(:approval_project_rule, project: project, applies_to_all_protected_branches: true)
        end

        context 'and there are other branch rules' do
          let_it_be(:branch_name_a) { TestEnv::BRANCH_SHA.each_key.first }
          let_it_be(:branch_name_b) { 'diff-*' }
          let_it_be(:protected_branch_a, freeze: false) do
            create(:protected_branch, project: project, name: branch_name_a)
          end

          let_it_be(:protected_branch_b) do
            create(:protected_branch, project: project, name: branch_name_b)
          end

          let(:branch_rule_a) { Projects::BranchRule.new(project, protected_branch_a) }
          let(:branch_rule_b) { Projects::BranchRule.new(project, protected_branch_b) }
          let(:branch_rule_b_data) { branch_rules_data.third }
          let(:branch_rule_a_data) { branch_rules_data.fourth }

          it_behaves_like 'a working graphql query'

          it 'includes all fields', :use_sql_query_cache, :aggregate_failures do
            expect(all_branches_rule_data).to include(
              'id' => all_branches_rule.to_global_id.to_s,
              'name' => all_branches_rule.name,
              'isDefault' => all_branches_rule.default_branch?,
              'isProtected' => all_branches_rule.protected?,
              'matchingBranchesCount' => all_branches_rule.matching_branches_count,
              'branchProtection' => all_branches_rule.branch_protection,
              'createdAt' => all_branches_rule.created_at.iso8601,
              'updatedAt' => all_branches_rule.updated_at.iso8601,
              'approvalRules' => be_kind_of(Hash),
              'externalStatusChecks' => be_kind_of(Hash)
            )
            approval_rules_data = all_branches_rule_data['approvalRules']['nodes']
            expect(approval_rules_data).to eq([{
              'id' => all_branches_approval_rule.to_global_id.to_s,
              'name' => all_branches_approval_rule.name,
              'type' => 'REGULAR',
              'approvalsRequired' => 0,
              'coverageMinimumThreshold' => nil
            }])
            external_checks_data = all_branches_rule_data['externalStatusChecks']['nodes']
            expect(external_checks_data).to eq([{
              'id' => all_branches_external_status_check.to_global_id.to_s,
              'name' => all_branches_external_status_check.name,
              'externalUrl' => all_branches_external_status_check.external_url,
              'hmac' => false
            }])
            expect(all_protected_branches_rule_data).to include(
              'id' => all_protected_branches_rule.to_global_id.to_s,
              'name' => all_protected_branches_rule.name,
              'isDefault' => all_protected_branches_rule.default_branch?,
              'isProtected' => all_protected_branches_rule.protected?,
              'matchingBranchesCount' => all_protected_branches_rule.matching_branches_count,
              'branchProtection' => all_protected_branches_rule.branch_protection,
              'createdAt' => all_protected_branches_rule.created_at.iso8601,
              'updatedAt' => all_protected_branches_rule.updated_at.iso8601,
              'approvalRules' => be_kind_of(Hash),
              'externalStatusChecks' => be_kind_of(Hash)
            )
            approval_rules_data = all_protected_branches_rule_data['approvalRules']['nodes']
            expect(approval_rules_data).to eq([{
              'id' => all_protected_branches_approval_rule.to_global_id.to_s,
              'name' => all_protected_branches_approval_rule.name,
              'type' => 'REGULAR',
              'approvalsRequired' => 0,
              'coverageMinimumThreshold' => nil
            }])

            expect(branch_rule_a_data).to include(
              'id' => branch_rule_a.to_global_id.to_s,
              'name' => branch_rule_a.name,
              'isDefault' => branch_rule_a.default_branch?,
              'isProtected' => branch_rule_a.protected?,
              'matchingBranchesCount' => branch_rule_a.matching_branches_count,
              'branchProtection' => hash_including(
                "allowForcePush" => false,
                "codeOwnerApprovalRequired" => false,
                "modificationBlockedByPolicy" => false,
                "protectedFromPushBySecurityPolicy" => false,
                "isGroupLevel" => false
              ),
              'createdAt' => branch_rule_a.created_at.iso8601,
              'updatedAt' => branch_rule_a.updated_at.iso8601,
              'approvalRules' => be_kind_of(Hash),
              'externalStatusChecks' => be_kind_of(Hash)
            )

            expect(branch_rule_b_data).to include(
              'id' => branch_rule_b.to_global_id.to_s,
              'name' => branch_rule_b.name,
              'isDefault' => branch_rule_b.default_branch?,
              'isProtected' => branch_rule_b.protected?,
              'matchingBranchesCount' => branch_rule_b.matching_branches_count,
              'branchProtection' => hash_including(
                "allowForcePush" => false,
                "codeOwnerApprovalRequired" => false,
                "modificationBlockedByPolicy" => false,
                "protectedFromPushBySecurityPolicy" => false,
                "isGroupLevel" => false
              ),
              'createdAt' => branch_rule_b.created_at.iso8601,
              'updatedAt' => branch_rule_b.updated_at.iso8601,
              'approvalRules' => be_kind_of(Hash),
              'externalStatusChecks' => be_kind_of(Hash)
            )
          end
        end

        context 'when there is a group branch rule' do
          let_it_be(:group_protected_branch, freeze: false) do
            create(:protected_branch, project: nil, group: project.group)
          end

          let!(:group_branch_rule) { Projects::BranchRule.new(project, group_protected_branch) }

          let(:group_branch_rules_data) do
            branch_rules_data.find { |rule| rule['id'] == group_branch_rule.to_global_id.to_s }
          end

          it 'returns the group branch rule without its protection details', :aggregate_failures do
            expect(group_branch_rules_data).to include(
              'id' => group_branch_rule.to_global_id.to_s,
              'name' => group_branch_rule.name,
              'isGroupLevel' => true,
              'branchProtection' => nil
            )
          end

          context 'when the user does have read_protected_branch abilities for the group' do
            let(:current_user) { group_maintainer }

            it 'includes all fields', :use_sql_query_cache, :aggregate_failures do
              expect(group_branch_rules_data).to include(
                'id' => group_branch_rule.to_global_id.to_s,
                'name' => group_branch_rule.name,
                'isGroupLevel' => true,
                'isDefault' => group_branch_rule.default_branch?,
                'isProtected' => group_branch_rule.protected?,
                'matchingBranchesCount' => group_branch_rule.matching_branches_count,
                'branchProtection' => hash_including(
                  "allowForcePush" => false,
                  "codeOwnerApprovalRequired" => false,
                  "modificationBlockedByPolicy" => false,
                  "protectedFromPushBySecurityPolicy" => false,
                  "isGroupLevel" => true
                ),
                'createdAt' => group_branch_rule.created_at.iso8601,
                'updatedAt' => group_branch_rule.updated_at.iso8601,
                'approvalRules' => be_kind_of(Hash),
                'externalStatusChecks' => be_kind_of(Hash)
              )
            end
          end
        end
      end

      context 'when custom rules are not persisted' do
        context 'and build_missing is true' do
          let(:build_missing) { true }

          it_behaves_like 'a working graphql query'

          it 'includes unpersisted custom rules', :use_sql_query_cache, :aggregate_failures do
            expect(all_branches_rule_data).to include(
              'id' => all_branches_rule.to_global_id.to_s,
              'name' => all_branches_rule.name,
              'isDefault' => all_branches_rule.default_branch?,
              'isProtected' => all_branches_rule.protected?,
              'matchingBranchesCount' => all_branches_rule.matching_branches_count,
              'branchProtection' => nil,
              'createdAt' => nil,
              'updatedAt' => nil,
              'approvalRules' => a_hash_including('nodes' => []),
              'externalStatusChecks' => a_hash_including('nodes' => [])
            )

            expect(all_protected_branches_rule_data).to include(
              'id' => all_protected_branches_rule.to_global_id.to_s,
              'name' => all_protected_branches_rule.name,
              'isDefault' => all_protected_branches_rule.default_branch?,
              'isProtected' => all_protected_branches_rule.protected?,
              'matchingBranchesCount' => all_protected_branches_rule.matching_branches_count,
              'branchProtection' => nil,
              'createdAt' => nil,
              'updatedAt' => nil,
              'approvalRules' => a_hash_including('nodes' => []),
              'externalStatusChecks' => a_hash_including('nodes' => [])
            )
          end
        end

        context 'and build_missing is false' do
          let(:build_missing) { false }

          it_behaves_like 'a working graphql query'

          it 'omits unpersisted custom branch rules', :use_sql_query_cache, :aggregate_failures do
            expect(branch_rules_data).not_to include(a_hash_including(name: 'All branches'))
            expect(branch_rules_data).not_to include(a_hash_including(name: 'All protected branches'))
          end
        end
      end
    end
  end
end
