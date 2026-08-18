# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ParamsFilteringService, feature_category: :code_review_workflow do
  let_it_be(:project_member) { create(:user) }
  let_it_be(:outsider) { create(:user) }
  let_it_be(:accessible_group) { create(:group, :private) }
  let_it_be(:accessible_subgroup) { create(:group, :private, parent: accessible_group) }
  let_it_be(:inaccessible_group) { create(:group, :private) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(merge_request, user, params) }

  describe '#execute' do
    before_all do
      project.add_maintainer(user)
      project.add_reporter(project_member)

      accessible_group.add_developer(user)
    end

    shared_examples_for('assigning users and groups') do
      before do
        allow(Ability).to receive(:allowed?).and_call_original

        allow(Ability)
          .to receive(:allowed?)
          .with(user, :update_approvers, merge_request)
          .and_return(can_update_approvers?)
      end

      context 'user can update approvers' do
        let(:can_update_approvers?) { true }

        it 'only assigns eligible users and groups' do
          params = service.execute

          rule1 = params[:approval_rules_attributes].first

          expect(rule1[:user_ids]).to contain_exactly(project_member.id)

          rule2 = params[:approval_rules_attributes].last
          expected_group_ids = expected_groups.map(&:id)

          expect(rule2[:user_ids]).to be_empty
          expect(rule2[:group_ids]).to contain_exactly(*expected_group_ids)
        end
      end

      context 'user cannot update approvers' do
        let(:can_update_approvers?) { false }

        it 'deletes the approval_rules_attributes from params' do
          expect(service.execute).not_to have_key(:approval_rules_attributes)
        end
      end
    end

    context 'create' do
      let(:merge_request) { build(:merge_request, target_project: project, source_project: project) }
      let(:params) do
        {
          title: 'Awesome merge_request',
          description: 'please fix',
          source_branch: 'feature',
          target_branch: 'master',
          force_remove_source_branch: '1',
          approval_rules_attributes: approval_rules_attributes
        }
      end

      it_behaves_like 'assigning users and groups' do
        let(:approval_rules_attributes) do
          [
            { name: 'foo', user_ids: [project_member.id, outsider.id] },
            { name: 'bar', user_ids: [outsider.id], group_ids: [accessible_group.id, accessible_subgroup.id, inaccessible_group.id] }
          ]
        end

        let(:expected_groups) { [accessible_group, accessible_subgroup] }
      end

      # When a project approval rule is genuinely empty, it should not be converted
      # an any_approver rule
      context 'empty project approval rule' do
        let(:approval_rules_attributes) { [{ name: 'Foo', user_ids: [], group_ids: [] }] }

        it 'adds empty rule', :aggregate_failures do
          rules = service.execute[:approval_rules_attributes]

          expect(rules.size).to eq(1)
          expect(rules[0]['name']).to eq('Foo')
          expect(rules[0]['user_ids']).to be_empty
          expect(rules[0]['group_ids']).to be_empty
          expect(rules[0].key?('rule_type')).to be_falsy
        end
      end

      context 'inapplicable user defined rules' do
        let_it_be(:source_rule) { create(:approval_project_rule, project: project) }
        let_it_be(:another_source_rule) { create(:approval_project_rule, project: project) }
        let(:protected_branch) { create(:protected_branch, project: project, name: 'stable-*') }

        let(:approval_rules_attributes) do
          [
            { name: another_source_rule.name, approval_project_rule_id: another_source_rule.id, user_ids: [project_member.id, outsider.id] }
          ]
        end

        before do
          source_rule.update!(protected_branches: [protected_branch])
        end

        context 'when multiple_approval_rules feature is available' do
          before do
            stub_licensed_features(multiple_approval_rules: true)
            project.clear_memoization(:user_defined_rules)
          end

          it 'adds inapplicable user defined rules' do
            params = service.execute
            approval_rules_attrs = params[:approval_rules_attributes]

            aggregate_failures do
              expect(approval_rules_attrs.size).to eq(2)

              expect(approval_rules_attrs.first).to include(
                name: another_source_rule.name,
                approval_project_rule_id: another_source_rule.id
              )

              expect(approval_rules_attrs.last).to include(
                name: source_rule.name,
                approval_project_rule_id: source_rule.id,
                user_ids: source_rule.user_ids,
                group_ids: source_rule.group_ids,
                approvals_required: source_rule.approvals_required,
                rule_type: source_rule.rule_type
              )
            end
          end
        end

        context 'when multiple_approval_rules feature is not available' do
          before do
            stub_licensed_features(multiple_approval_rules: false)
          end

          it 'does not add inapplicable user defined rules' do
            params = service.execute
            approval_rules_attrs = params[:approval_rules_attributes]

            aggregate_failures do
              expect(approval_rules_attrs.size).to eq(1)
              expect(approval_rules_attrs.first).to include(
                name: another_source_rule.name,
                approval_project_rule_id: another_source_rule.id
              )
            end
          end
        end
      end

      context 'any approver rule' do
        let(:can_update_approvers?) { true }
        let(:approval_rules_attributes) do
          [
            { user_ids: [], group_ids: [], name: '' }
          ]
        end

        it 'sets rule type for the rules attributes' do
          params = service.execute
          rule = params[:approval_rules_attributes].first

          expect(rule[:rule_type]).to eq(:any_approver)
          expect(rule[:name]).to eq('All Members')
        end
      end

      # A test case for https://gitlab.com/gitlab-org/gitlab/-/issues/208978#note_353379792
      # Approval project rules with any_approver type have groups, but they shouldn't
      context 'any approver rule from a project rule' do
        let(:can_update_approvers?) { true }
        let(:approval_rules_attributes) do
          [
            { user_ids: [""], group_ids: [""], approval_project_rule_id: approval_rule.id }
          ]
        end

        context 'and the project rule has hidden groups' do
          let(:approval_rule) do
            create(:approval_project_rule, project: project, rule_type: :any_approver).tap do |rule|
              rule.groups << create(:group, :private)
            end
          end

          it 'sets rule type for the rules attributes' do
            params = service.execute
            rule = params[:approval_rules_attributes].first

            expect(rule[:rule_type]).to eq(:any_approver)
            expect(rule[:name]).to eq('All Members')
          end
        end
      end
    end

    context 'update' do
      let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
      let_it_be(:existing_private_group) { create(:group, :private) }
      let_it_be(:rule1) { create(:approval_merge_request_rule, merge_request: merge_request, users: [create(:user)]) }
      let_it_be(:rule2) { create(:approval_merge_request_rule, merge_request: merge_request, groups: [existing_private_group]) }
      let_it_be(:rule3) { create(:report_approver_rule, :scan_finding, merge_request: merge_request) }
      let_it_be(:rule4) { create(:report_approver_rule, :license_scanning, merge_request: merge_request) }
      let_it_be(:rule5) { create(:code_owner_rule, merge_request: merge_request) }

      it_behaves_like 'assigning users and groups' do
        let(:params) do
          {
            approval_rules_attributes: [
              { id: rule1.id, name: 'foo', user_ids: [project_member.id, outsider.id] },
              { id: rule2.id, name: 'bar', user_ids: [outsider.id], group_ids: [accessible_group.id, inaccessible_group.id] }
            ]
          }
        end

        let(:expected_groups) { [accessible_group, existing_private_group] }
      end

      context 'with non user defined approval rules' do
        let(:params) do
          {
            approval_rules_attributes: [
              { id: rule1.id, name: 'foo', approvals_required: 0 },
              { id: rule2.id, name: 'bar', approvals_required: 0 },
              { id: rule3.id, name: 'bar', approvals_required: 0 },
              { id: rule4.id, name: 'bar', approvals_required: 0 },
              { id: rule5.id, name: 'foo', approvals_required: 0 }
            ]
          }
        end

        it 'filters non user defined approval rules' do
          filtered_params = service.execute

          expect(filtered_params[:approval_rules_attributes].pluck("id")).to match_array([rule1.id, rule2.id])
        end
      end

      context 'inapplicable user defined rules' do
        let!(:source_rule) { create(:approval_project_rule, project: project) }
        let(:protected_branch) { create(:protected_branch, project: project, name: 'stable-*') }
        let(:approval_rules_attrs) { service.execute[:approval_rules_attributes] }

        let(:params) do
          {
            approval_rules_attributes: [
              { id: rule1.id, name: 'foo', user_ids: [project_member.id, outsider.id] }
            ]
          }
        end

        before do
          source_rule.update!(protected_branches: [protected_branch])
        end

        it 'does not add inapplicable user defined rules' do
          aggregate_failures do
            expect(approval_rules_attrs.size).to eq(1)
            expect(approval_rules_attrs.first[:name]).to eq('foo')
          end
        end

        context 'when reset_approval_rules_to_defaults is true' do
          let(:params) do
            {
              approval_rules_attributes: [
                { id: rule1.id, name: 'foo', user_ids: [project_member.id, outsider.id] }
              ],
              reset_approval_rules_to_defaults: true
            }
          end

          context 'when multiple_approval_rules feature is available' do
            before do
              stub_licensed_features(multiple_approval_rules: true)
              project.clear_memoization(:user_defined_rules)
            end

            it 'adds inapplicable user defined rules' do
              aggregate_failures do
                expect(approval_rules_attrs.size).to eq(2)

                expect(approval_rules_attrs.first).to include(
                  id: rule1.id,
                  name: 'foo'
                )

                expect(approval_rules_attrs.last).to include(
                  name: source_rule.name,
                  approval_project_rule_id: source_rule.id,
                  user_ids: source_rule.user_ids,
                  group_ids: source_rule.group_ids,
                  approvals_required: source_rule.approvals_required,
                  rule_type: source_rule.rule_type
                )
              end
            end
          end

          context 'when multiple_approval_rules feature is not available' do
            before do
              stub_licensed_features(multiple_approval_rules: false)
            end

            it 'does not add inapplicable user defined rules' do
              aggregate_failures do
                expect(approval_rules_attrs.size).to eq(1)
                expect(approval_rules_attrs.first).to include(
                  id: rule1.id,
                  name: 'foo'
                )
              end
            end
          end
        end
      end

      context 'with remove_hidden_groups being true' do
        it_behaves_like 'assigning users and groups' do
          let(:params) do
            {
              approval_rules_attributes: [
                { id: rule1.id, name: 'foo', user_ids: [project_member.id, outsider.id] },
                { id: rule2.id, name: 'bar', user_ids: [outsider.id], group_ids: [accessible_group.id, inaccessible_group.id], remove_hidden_groups: true }
              ]
            }
          end

          let(:expected_groups) { [accessible_group] }
        end
      end
    end
  end

  describe 'cross-organization group isolation' do
    let_it_be(:organization) { create(:organization, :isolated) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:isolated_project, freeze: false) { create(:project, :repository, organization: organization) }

    let_it_be(:same_org_group) { create(:group, organization: organization) }
    let_it_be(:cross_org_group) { create(:group, organization: other_organization) }

    let_it_be(:actor) { create(:user, organization: organization) }

    before_all do
      isolated_project.add_maintainer(actor)
      same_org_group.add_developer(actor)
      cross_org_group.add_developer(actor)
    end

    context 'when the project organization is isolated' do
      let(:merge_request) do
        create(:merge_request, target_project: isolated_project, source_project: isolated_project)
      end

      it 'excludes cross-org groups from visible_group_ids' do
        params = {
          approval_rules_attributes: [
            {
              name: 'rule',
              group_ids: [same_org_group.id, cross_org_group.id]
            }
          ]
        }

        result = described_class.new(merge_request, actor, params).execute

        rule_attrs = result[:approval_rules_attributes].first
        expect(rule_attrs[:group_ids]).to contain_exactly(same_org_group.id)
      end
    end

    context 'when the project organization is not isolated' do
      let_it_be(:non_isolated_project, freeze: false) { create(:project, :repository, organization: other_organization) }

      let(:merge_request) do
        create(:merge_request, target_project: non_isolated_project, source_project: non_isolated_project)
      end

      before_all do
        non_isolated_project.add_maintainer(actor)
      end

      it 'allows groups from any organization' do
        params = {
          approval_rules_attributes: [
            { name: 'rule', group_ids: [same_org_group.id, cross_org_group.id] }
          ]
        }

        result = described_class.new(merge_request, actor, params).execute

        rule_attrs = result[:approval_rules_attributes].first
        expect(rule_attrs[:group_ids]).to include(cross_org_group.id, same_org_group.id)
      end
    end
  end
end
