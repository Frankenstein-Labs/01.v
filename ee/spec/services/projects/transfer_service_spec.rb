# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TransferService, feature_category: :groups_and_projects do
  include EE::GeoHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, owners: user) }
  let_it_be_with_refind(:project) { create(:project, :public, :legacy_storage, namespace: user.namespace) }

  subject { described_class.new(project, user) }

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:fail_condition!) do
        expect(project).to receive(:has_container_registry_tags?).and_return(true)

        def operation
          subject.execute(group)
        end
      end

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: project.id,
          entity_type: 'Project',
          details: {
            change: 'namespace',
            event_name: "project_namespace_updated",
            from: project.old_path_with_namespace,
            to: project.full_path,
            author_name: user.name,
            author_class: user.class.name,
            target_id: project.id,
            target_type: 'Project',
            target_details: project.full_path,
            custom_message: "Changed namespace from #{project.old_path_with_namespace} to #{project.full_path}"
          }
        }
      end
    end
  end

  context 'missing epics applied to issues' do
    it 'delegates transfer to Epics::TransferService' do
      expect_next_instance_of(Epics::TransferService, user, project.group, project) do |epics_transfer_service|
        expect(epics_transfer_service).to receive(:execute).once.and_call_original
      end

      subject.execute(group)
    end
  end

  context 'transfering current status' do
    let(:transfer_service) { instance_double(WorkItems::Widgets::Statuses::TransferService) }
    let(:namespace_ids) { [project.project_namespace_id] }

    it 'delegates transfer to WorkItems::Widgets::Statuses::TransferService' do
      expect(WorkItems::Widgets::Statuses::TransferService).to receive(:new).with(
        old_root_namespace: project.namespace.root_ancestor,
        new_root_namespace: group,
        project_namespace_ids: namespace_ids
      ).and_return(transfer_service)
      expect(transfer_service).to receive(:execute)

      subject.execute(group)
    end
  end

  describe 'elasticsearch indexing', feature_category: :global_search do
    it 'delegates transfer to Elastic::ProjectTransferWorker and ::Search::Zoekt::ProjectTransferWorker' do
      expect(::Elastic::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id, group.id).once
      expect(::Search::Zoekt::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id).once

      subject.execute(group)
    end
  end

  describe 'security policy project', feature_category: :security_policy_management do
    context 'when project has licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'delegates transfer to Security::Policies::ProjectTransferWorker' do
        expect(::Security::Policies::ProjectTransferWorker).to receive(:perform_async).with(project.id, user.id, project.namespace.id, group.id).once

        subject.execute(group)
      end
    end

    context 'when project does not have licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not delegate transfer to Security::Policies::ProjectTransferWorker' do
        expect(::Security::Policies::ProjectTransferWorker).not_to receive(:perform_async)

        subject.execute(group)
      end
    end
  end

  describe 'updating paid features' do
    it 'calls the ::EE::Projects::RemovePaidFeaturesService to update paid features' do
      expect_next_instance_of(::EE::Projects::RemovePaidFeaturesService, project) do |service|
        expect(service).to receive(:execute).with(group).and_call_original
      end

      subject.execute(group)
    end

    # explicit testing of the pipeline subscriptions cleanup to verify `run_after_commit` block is executed
    context 'with pipeline subscriptions', :saas do
      before do
        create(:license, plan: License::PREMIUM_PLAN)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when target namespace has a free plan' do
        it 'schedules cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async)
            .with(project.id)
            .and_call_original

          subject.execute(group)
        end
      end
    end
  end

  describe 'deleting compliance framework setting' do
    context 'when the project has a compliance framework setting' do
      let!(:compliance_framework_setting) { create(:compliance_framework_project_setting, project: project) }

      context 'when the project is transferring under the same top level group' do
        let_it_be_with_reload(:project) { create(:project, group: group) }
        let_it_be(:sub_group) { create(:group, parent: group) }

        it 'does not delete the compliance framework setting' do
          subject.execute(sub_group)

          expect(project.reload.compliance_framework_settings).to eq([compliance_framework_setting])
        end
      end

      context 'when the project is transferring under a nested sub group' do
        let_it_be(:sub_group) { create(:group, parent: create(:group, :public)) }
        let_it_be_with_reload(:project) { create(:project, group: sub_group) }
        let_it_be(:nested_sub_group) { create(:group, parent: sub_group) }

        before_all do
          sub_group.add_owner(user)
        end

        it 'does not delete the compliance framework setting' do
          subject.execute(nested_sub_group)

          expect(project.reload.compliance_framework_settings).to eq([compliance_framework_setting])
        end
      end

      context 'when the project is transferring to a new group' do
        let_it_be(:old_group) { create(:group, :public, owners: user) }
        let_it_be_with_reload(:project) { create(:project, group: old_group) }

        before do
          stub_licensed_features(extended_audit_events: true, external_audit_events: true)
        end

        it 'deletes the compliance framework setting' do
          subject.execute(group)

          expect(project.reload.compliance_framework_settings).to eq([])
        end

        it 'creates transfer and compliance audit events' do
          expect { subject.execute(group) }.to change { AuditEventReader.count }.by(2)

          event_names = AuditEventReader.order(id: :desc).first(2).map do |event|
            event.details.with_indifferent_access[:event_name]
          end

          expect(event_names).to include(
            'project_namespace_updated',
            'compliance_framework_deleted'
          )
        end
      end
    end

    context 'when the project does not have a compliance framework setting' do
      it 'does not raise an error' do
        expect { subject.execute(group) }.not_to raise_error
      end

      it 'does not change the compliance framework settings count' do
        expect { subject.execute(group) }.not_to change { ::ComplianceManagement::ComplianceFramework::ProjectSettings.count }
      end
    end
  end

  context 'update_compliance_standards_adherence' do
    let_it_be(:old_group) { create(:group, owners: user) }
    let_it_be_with_reload(:project) { create(:project, group: old_group) }
    let!(:adherence) { create(:compliance_standards_adherence, :gitlab, project: project) }

    before do
      stub_licensed_features(group_level_compliance_dashboard: true)
    end

    it "updates the project's compliance standards adherence with new namespace id" do
      expect(project.compliance_standards_adherence.first.namespace_id).to eq(old_group.id)

      subject.execute(group)

      expect(project.reload.compliance_standards_adherence.first.namespace_id).to eq(group.id)
    end
  end

  describe 'deleting compliance statuses' do
    let_it_be(:subgroup1) { create(:group, parent: group) }
    let_it_be_with_reload(:project) { create(:project, group: subgroup1) }
    let_it_be(:subgroup2) { create(:group, parent: group) }
    let_it_be_with_reload(:other_group) { create(:group) }
    let_it_be(:framework1) { create(:compliance_framework, :first, namespace: group) }
    let_it_be(:framework2) { create(:compliance_framework, :second, namespace: group) }

    before_all do
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework1)
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework2)

      subgroup1.add_owner(user)
      subgroup2.add_owner(user)
      other_group.add_owner(user)
    end

    context 'when transferring to same top-level group' do
      it 'enqueues project compliance statuses removal for the framework' do
        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework1.id, { "skip_framework_check" => true }).once.ordered

        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework2.id, { "skip_framework_check" => true }).once.ordered

        subject.execute(group)
      end
    end

    context 'when transferring to subgroup of same top level group' do
      it 'enqueues project compliance statuses removal for the framework' do
        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework1.id, { "skip_framework_check" => true }).once.ordered

        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework2.id, { "skip_framework_check" => true }).once.ordered

        subject.execute(subgroup2)
      end
    end

    context 'when transferring to other group' do
      it 'enqueues project compliance statuses removal for the framework' do
        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework1.id, { "skip_framework_check" => true }).once.ordered

        expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
          .to receive(:perform_async)
                .with(project.id, framework2.id, { "skip_framework_check" => true }).once.ordered

        subject.execute(other_group)
      end

      context 'and project has a secret manager' do
        let_it_be_with_reload(:deprovision_project) { create(:project, group: subgroup1) }
        let_it_be(:secrets_manager) { create(:project_secrets_manager, project: deprovision_project) }

        subject(:deprovision_transfer_service) { described_class.new(deprovision_project, user) }

        it 'calls the deprovision service to destroy the SM in the same transaction, with enqueue_worker: false' do
          fake_service = instance_double(
            SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService
          )
          expect(SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService)
            .to receive(:new).with(secrets_manager, user, project_id: secrets_manager.project_id)
            .and_return(fake_service)
          expect(fake_service).to receive(:execute).with(enqueue_worker: false)
            .and_return(ServiceResponse.success(payload: { project_secrets_manager: secrets_manager }))

          deprovision_transfer_service.execute(other_group)
        end
      end

      context 'and project does not have a secret manager' do
        let_it_be_with_reload(:deprovision_project) { create(:project, group: subgroup1) }

        subject(:deprovision_transfer_service) { described_class.new(deprovision_project, user) }

        it 'does not call the deprovision service' do
          expect(SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService).not_to receive(:new)

          deprovision_transfer_service.execute(other_group)
        end
      end
    end
  end
end
