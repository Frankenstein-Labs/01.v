# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranches::UpdateService, feature_category: :compliance_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let(:branch_name) { 'feature' }
  let(:protected_branch) { create(:protected_branch, name: branch_name, project: project) }
  let(:user) { project.first_owner }

  subject(:service) { described_class.new(project, user, params) }

  describe '#execute' do
    context 'with invalid params' do
      let(:params) do
        {
          name: branch_name,
          push_access_levels_attributes: [{ access_level: Gitlab::Access::MAINTAINER }]
        }
      end

      it "does not add a security audit event entry" do
        expect { service.execute(protected_branch) }.not_to change { AuditEventReader.count }
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          name: branch_name,
          merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
          push_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }]
        }
      end

      it 'adds security audit event entries' do
        expect { service.execute(protected_branch) }.to change { AuditEventReader.count }.by(2)
      end
    end
  end

  describe 'push access levels under a prevent-pushing policy' do
    let(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let(:existing_push_access_level) { protected_branch.push_access_levels.first }

    include_context 'with approval security policy preventing force pushing'

    context 'when the update genuinely changes push access levels' do
      let(:params) do
        {
          name: branch_name,
          push_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }]
        }
      end

      it 'blocks the change with a policy violation' do
        expect { service.execute(protected_branch) }
          .to raise_error(::EE::ProtectedBranches::BasePolicyCheck::PolicyViolationError)
      end
    end

    context 'when security orchestration policies are not licensed',
      feature_category: :security_policy_management do
      let(:params) do
        {
          name: branch_name,
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: Gitlab::Access::DEVELOPER }
          ]
        }
      end

      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'persists the push access level change', :aggregate_failures do
        expect { service.execute(protected_branch) }.not_to raise_error
        expect(protected_branch.reload.push_access_levels.map(&:access_level))
          .to contain_exactly(Gitlab::Access::DEVELOPER)
      end
    end

    context 'when the submitted push access levels match the stored levels' do
      # Non-GraphQL callers (REST API, settings form) resubmit the full push
      # access state on every save even when only merge access changed. Echoing
      # back unchanged push levels must not be read as a push-access change and
      # blocked by the policy.
      let(:params) do
        {
          name: branch_name,
          merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: existing_push_access_level.access_level }
          ]
        }
      end

      it 'does not raise and leaves push access levels unchanged', :aggregate_failures do
        expect { service.execute(protected_branch) }.not_to raise_error
        expect(protected_branch.reload.push_access_levels.map(&:access_level))
          .to contain_exactly(Gitlab::Access::MAINTAINER)
      end
    end

    context 'when push access levels are omitted entirely' do
      let(:params) do
        { name: branch_name, merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }] }
      end

      it 'does not raise' do
        expect { service.execute(protected_branch) }.not_to raise_error
      end
    end
  end

  describe 'blocking scan result policies' do
    context 'with project-level protected branch' do
      let(:params) { { name: branch_name.reverse } }

      let(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      include_context 'with approval security policy blocking protected branches'

      it 'raises' do
        expect { service.execute(protected_branch) }.to raise_error(::Gitlab::Access::AccessDeniedError)
      end

      context 'when the matching rule is soft-deleted' do
        before do
          approval_policy_rule_blocking_protected_branches.update!(rule_index: -1)
        end

        it 'does not raise' do
          expect { service.execute(protected_branch) }.not_to raise_error
        end
      end

      context 'when policy is in warn mode' do
        before do
          updated_content = approval_policy_blocking_protected_branches.content.merge(
            enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN
          )

          approval_policy_blocking_protected_branches.update!(content: updated_content)
        end

        it 'does not raise' do
          expect { service.execute(protected_branch) }.not_to raise_error
        end

        context 'when attempting to toggle force-pushing' do
          let(:params) { { name: branch_name, allow_force_push: true } }

          include_context 'with approval security policy preventing force pushing' do
            let(:approval_policy_preventing_force_pushing_policy_index) { 1 }
          end

          before do
            updated_content = approval_policy_preventing_force_pushing.content.merge(
              enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN
            )

            approval_policy_preventing_force_pushing.update!(content: updated_content)
          end

          it 'does not raise' do
            expect { service.execute(protected_branch) }.not_to raise_error
          end
        end
      end
    end

    context 'with group-level protected branch' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:protected_branch) { create(:protected_branch, project_id: nil, namespace_id: group.id) }

      before_all do
        group.add_owner(user)
      end

      context 'with blocking scan result policy' do
        let(:params) { { name: branch_name.reverse } }

        let(:policy_configuration) do
          create(:security_orchestration_policy_configuration, :namespace, namespace_id: group.id)
        end

        shared_examples 'prevents update of protected branch' do
          it 'raises' do
            expect { service.execute(protected_branch) }.to raise_error(::Gitlab::Access::AccessDeniedError)
          end
        end

        include_context 'with approval security policy blocking protected branches' do
          include_examples 'prevents update of protected branch'
        end

        include_context 'with approval policy blocking group-level protected branches' do
          include_examples 'prevents update of protected branch'
        end
      end
    end
  end
end
