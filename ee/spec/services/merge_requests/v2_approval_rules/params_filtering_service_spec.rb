# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::V2ApprovalRules::ParamsFilteringService, feature_category: :source_code_management do
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

    context 'when filtering create params' do
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

      context 'with v2_approval_rules_attributes' do
        let(:params) do
          {
            title: 'Awesome merge_request',
            description: 'please fix',
            source_branch: 'feature',
            target_branch: 'master',
            v2_approval_rules_attributes: [{ name: 'Test Rule', approvals_required: 2 }]
          }
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability)
            .to receive(:allowed?)
                  .with(user, :update_approvers, merge_request)
                  .and_return(can_update_approvers?)
        end

        context 'when user can update approvers' do
          let(:can_update_approvers?) { true }

          before do
            stub_feature_flags(v2_approval_rules: true)
          end

          it 'keeps v2_approval_rules_attributes' do
            expect(service.execute).to include(:v2_approval_rules_attributes)
          end

          context 'when approver_group_ids are provided' do
            let(:params) do
              {
                v2_approval_rules_attributes: [
                  { name: 'rule', approver_group_ids: [accessible_group.id, inaccessible_group.id] }
                ]
              }
            end

            it 'filters out inaccessible groups' do
              result = service.execute

              expect(result[:v2_approval_rules_attributes].first[:approver_group_ids])
                .to contain_exactly(accessible_group.id)
            end
          end

          context 'when approver_user_ids are provided' do
            let(:params) do
              {
                v2_approval_rules_attributes: [
                  { name: 'rule', approver_user_ids: [project_member.id, outsider.id] }
                ]
              }
            end

            it 'filters out non-project-members' do
              result = service.execute

              expect(result[:v2_approval_rules_attributes].first[:approver_user_ids])
                .to contain_exactly(project_member.id)
            end
          end

          context 'when all provided approvers are ineligible and name is blank' do
            let(:params) do
              {
                v2_approval_rules_attributes: [
                  { name: '', approver_user_ids: [outsider.id], approver_group_ids: [inaccessible_group.id] }
                ]
              }
            end

            it 'converts the rule to any_approver', :aggregate_failures do
              result = service.execute
              rule = result[:v2_approval_rules_attributes].first

              expect(rule[:rule_type]).to eq(:any_approver)
              expect(rule[:name]).to eq('All Members')
            end
          end

          context 'when all provided approvers are ineligible but rule has a name' do
            let(:params) do
              {
                v2_approval_rules_attributes: [
                  { name: 'named rule', approver_user_ids: [outsider.id], approver_group_ids: [inaccessible_group.id] }
                ]
              }
            end

            it 'does not convert to any_approver' do
              result = service.execute
              rule = result[:v2_approval_rules_attributes].first

              expect(rule[:rule_type]).to be_nil
            end
          end

          context 'when both approver_group_ids and approver_user_ids are provided' do
            let(:params) do
              {
                v2_approval_rules_attributes: [
                  {
                    name: 'rule',
                    approver_group_ids: [accessible_group.id, inaccessible_group.id],
                    approver_user_ids: [project_member.id, outsider.id]
                  }
                ]
              }
            end

            it 'only retains visible groups and project members', :aggregate_failures do
              result = service.execute
              rule = result[:v2_approval_rules_attributes].first

              expect(rule[:approver_group_ids]).to contain_exactly(accessible_group.id)
              expect(rule[:approver_user_ids]).to contain_exactly(project_member.id)
            end
          end
        end

        context 'when user cannot update approvers' do
          let(:can_update_approvers?) { false }

          it 'removes v2_approval_rules_attributes' do
            expect(service.execute).not_to include(:v2_approval_rules_attributes)
          end
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
        build(:merge_request, target_project: isolated_project, source_project: isolated_project)
      end

      context 'when using v2_approval_rules_attributes' do
        it 'excludes cross-org groups from approver_group_ids' do
          params = {
            v2_approval_rules_attributes: [
              { name: 'rule', approver_group_ids: [same_org_group.id, cross_org_group.id] }
            ]
          }

          result = described_class.new(merge_request, actor, params).execute

          expect(result[:v2_approval_rules_attributes].first[:approver_group_ids])
            .to contain_exactly(same_org_group.id)
        end
      end
    end

    context 'when the project organization is not isolated' do
      let_it_be(:non_isolated_project, freeze: false) do
        create(:project, :repository, organization: other_organization)
      end

      let(:merge_request) do
        build(:merge_request, target_project: non_isolated_project, source_project: non_isolated_project)
      end

      before_all do
        non_isolated_project.add_maintainer(actor)
      end

      context 'when using v2_approval_rules_attributes' do
        it 'allows groups from any organization' do
          params = {
            v2_approval_rules_attributes: [
              { name: 'rule', approver_group_ids: [same_org_group.id, cross_org_group.id] }
            ]
          }

          result = described_class.new(merge_request, actor, params).execute

          expect(result[:v2_approval_rules_attributes].first[:approver_group_ids])
            .to include(same_org_group.id, cross_org_group.id)
        end
      end
    end
  end
end
