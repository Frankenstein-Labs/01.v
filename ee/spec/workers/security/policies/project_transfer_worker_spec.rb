# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policies::ProjectTransferWorker, :sidekiq_inline, feature_category: :security_policy_management do
  let_it_be(:current_user) { create(:user) }

  let_it_be(:old_namespace) { create(:group) }
  let_it_be(:new_namespace) { create(:group) }
  let_it_be(:project) { create(:project, group: new_namespace) }

  subject(:perform_worker) do
    described_class.new.perform(project.id, current_user.id, old_namespace.id, new_namespace.id)
  end

  before_all do
    project.add_maintainer(current_user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#perform' do
    context 'when project has security orchestration policies' do
      let_it_be(:policy_config) do
        create(:security_orchestration_policy_configuration, project: project, namespace: nil)
      end

      let_it_be(:security_policy) do
        create(:security_policy, security_orchestration_policy_configuration: policy_config, linked_projects: [project])
      end

      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:approval_project_rule) do
        create(:approval_project_rule, :scan_finding, project: project,
          security_orchestration_policy_configuration_id: policy_config.id)
      end

      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: policy_config, project: project)
      end

      let_it_be(:software_license_policy) do
        create(:software_license_policy, project: project,
          scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be(:scan_result_policy_violation) do
        create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

      before_all do
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
        project.add_guest(security_policy_bot)
      end

      it 'removes associated entities' do
        expect { perform_worker }
          .to change { project.approval_rules.count }.from(1).to(0)
          .and change { project.scan_result_policy_reads.count }.from(1).to(0)
          .and change { project.software_license_policies.count }.from(1).to(0)
          .and change { project.scan_result_policy_violations.count }.from(1).to(0)
      end

      it 'removes security policy project links' do
        expect { perform_worker }
          .to change { project.security_policy_project_links.count }.from(1).to(0)
          .and change { project.approval_policy_rule_project_links.count }.from(1).to(0)
      end

      it 'deletes security_orchestration_policy_configuration' do
        perform_worker

        expect { policy_config.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'removes the security_policy_bot from the project' do
        expect { perform_worker }.to change { project.reload.security_policy_bot }.from(security_policy_bot).to(nil)
      end
    end

    context 'when project has inherited security orchestration policies' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:new_namespace) { create(:group, parent: group) }
      let_it_be_with_reload(:old_namespace) { create(:group, parent: new_namespace) }
      let_it_be(:project) { create(:project, group: new_namespace) }
      let_it_be_with_reload(:group_configuration) do
        create(:security_orchestration_policy_configuration, project: nil, namespace: group)
      end

      let_it_be_with_reload(:sub_group_configuration) do
        create(:security_orchestration_policy_configuration, project: nil, namespace: new_namespace)
      end

      let_it_be(:group_approval_rule) do
        create(:approval_project_rule, :scan_finding, :requires_approval, project: project,
          security_orchestration_policy_configuration: group_configuration)
      end

      let_it_be(:sub_group_approval_rule) do
        create(:approval_project_rule, :scan_finding, :requires_approval, project: project,
          security_orchestration_policy_configuration: sub_group_configuration)
      end

      let_it_be(:security_policy) do
        create(:security_policy, security_orchestration_policy_configuration: sub_group_configuration,
          linked_projects: [project])
      end

      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: sub_group_configuration,
          project: project)
      end

      let_it_be(:software_license_policy) do
        create(:software_license_policy, project: project,
          scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be(:scan_result_policy_violation) do
        create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read)
      end

      before_all do
        new_namespace.add_owner(current_user)
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'deletes associated entities from inherited policies' do
        perform_worker

        expect { group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { sub_group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { scan_result_policy_read.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { software_license_policy.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { scan_result_policy_violation.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end

      it 'triggers sync workers' do
        expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async).once.with(project.id,
          group_configuration.id)
        expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async).once.with(project.id,
          sub_group_configuration.id)

        perform_worker
      end

      it 'creates a security policy bot' do
        expect_next_instance_of(::Security::Orchestration::CreateBotService) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        perform_worker
      end
    end

    context 'when project does not have security orchestration policies' do
      let_it_be(:project) { create(:project) }

      it 'does not call Security::Orchestration::UnassignService' do
        expect(::Security::Orchestration::UnassignService).not_to receive(:new)

        perform_worker
      end
    end

    context 'when feature is not available' do
      let_it_be(:policy_config) do
        create(:security_orchestration_policy_configuration, project: project, namespace: nil)
      end

      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not trigger any sync workers or unassign service' do
        expect(Security::SyncProjectPoliciesWorker).not_to receive(:perform_async)
        expect(::Security::Orchestration::UnassignService).not_to receive(:new)

        perform_worker
      end
    end

    context 'when current_user is nil' do
      subject(:perform_worker) do
        described_class.new.perform(project.id, nil, old_namespace.id, new_namespace.id)
      end

      it 'does not call CreateBotService and UnassignService' do
        expect(::Security::Orchestration::CreateBotService).not_to receive(:new)
        expect(::Security::Orchestration::UnassignService).not_to receive(:new)
        expect(Users::DestroyService).not_to receive(:new)

        perform_worker
      end
    end
  end
end
