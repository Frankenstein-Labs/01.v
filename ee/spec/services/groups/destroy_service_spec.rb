# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DestroyService, feature_category: :groups_and_projects do
  include ::EE::GeoHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let!(:group) { create(:group) }

  before do
    group.add_owner(user)
  end

  subject { described_class.new(group, user, {}) }

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { subject.execute }
      let(:fail_condition!) do
        expect(group).to receive(:destroy).and_return(group)
      end

      let_it_be(:event_type, freeze: false) { 'group_destroyed' }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: group.id,
          entity_type: 'Group',
          details: {
            remove: 'group',
            author_name: user.name,
            author_class: user.class.name,
            event_name: "group_destroyed",
            target_id: group.id,
            target_type: 'Group',
            target_details: group.full_path,
            custom_message: 'Group destroyed'
          }
        }
      end
    end
  end

  context 'streaming audit event for sub group' do
    let_it_be(:parent_group, freeze: false) { create :group }
    let(:group) { create :group, parent: parent_group }

    subject { described_class.new(group, user, {}).execute }

    before_all do
      parent_group.add_owner(user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
      create(:audit_events_group_external_streaming_destination, group: parent_group)
    end

    it 'sends the audit streaming event with json format' do
      expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
        'group_destroyed',
        nil,
        a_string_including("group_entity_id\":#{parent_group.id}"))

      subject
    end
  end

  context 'dependency_proxy_blobs' do
    let_it_be(:blob, freeze: false) { create(:dependency_proxy_blob) }
    let_it_be(:group, freeze: false) { blob.group }

    before_all do
      group.add_owner(user)
    end

    it 'destroys the dependency proxy blobs' do
      expect { subject.execute }.to change { DependencyProxy::Blob.count }.by(-1)
    end
  end

  context 'when on a Geo primary site' do
    let_it_be(:geo_primary_site, freeze: false) { create(:geo_node, :primary) }

    before do
      stub_current_geo_node(geo_primary_site)
    end

    context 'when group_wiki_repository does not exist' do
      it 'does not call replicator to update Geo' do
        expect_next_instance_of(Geo::GroupWikiRepositoryReplicator).never

        subject.execute
      end
    end

    it 'calls replicator to update Geo' do
      group.wiki.create_wiki_repository

      expect(group.group_wiki_repository.replicator).to receive(:geo_handle_after_destroy)

      subject.execute
    end
  end

  context 'when not on a Geo primary site' do
    it 'does not call replicator to update Geo' do
      group.wiki.create_wiki_repository

      expect(group.group_wiki_repository.replicator).not_to receive(:geo_handle_after_destroy)

      subject.execute
    end
  end

  context 'when group epics have parent epic outside of group' do
    let!(:parent_group) { create(:group) }
    let!(:group) { create(:group, parent: parent_group) }
    let!(:parent_epic1) { create(:epic, group: parent_group) }
    let!(:parent_epic2) { create(:epic, group: parent_group) }
    let!(:parent_epic3) { create(:epic, group: parent_group) }
    let!(:epic1) { create(:epic, group: group, parent: parent_epic1) }
    let!(:epic2) { create(:epic, group: group, parent: parent_epic2) }
    let!(:epic3) { create(:epic, group: group, parent: parent_epic3) }
    # update should not be called for this as parent is in the same group:
    let!(:epic4) { create(:epic, group: group, parent: epic2) }

    before do
      group.add_owner(user)
    end

    it 'schedules cache update for associated epics in batches' do
      stub_const('::Epics::UpdateCachedMetadataWorker::BATCH_SIZE', 2)

      expect(::Epics::UpdateCachedMetadataWorker).to receive(:bulk_perform_in) do |delay, ids|
        expect(delay).to eq(1.minute)
        expect(ids.map(&:first).map(&:length)).to eq([2, 1])
        expect(ids.flatten).to match_array([parent_epic1.id, parent_epic2.id, parent_epic3.id])
      end.once

      subject.execute
    end
  end

  context 'associated records' do
    let!(:service_account) { create(:service_account, provisioned_by_group: group) }
    let!(:service_account_another_group) { create(:service_account, provisioned_by_group: create(:group)) }
    let!(:provisioned_user) { create(:user, provisioned_by_group: group) }

    it 'deletes group serviced accounts and user bots', :sidekiq_inline do
      subject.execute

      expect(
        Users::GhostUserMigration.where(user: service_account, initiator_user: user)
      ).to be_exists
      expect(
        Users::GhostUserMigration.where(user: service_account_another_group, initiator_user: user)
      ).to be_empty
      expect(
        Users::GhostUserMigration.where(user: provisioned_user, initiator_user: user)
      ).to be_empty
    end
  end

  context 'when group has a secrets manager' do
    # The destroy hook no longer calls `InitiateDeprovisionService`. The
    # FK on `group_secrets_managers.group_id` is `ON DELETE CASCADE`, so
    # destroying the group also deletes the SM row, which fires the
    # `enqueue_gsm_deprovision_task_after_delete` trigger and inserts a
    # deprovision maintenance task with the snapshot ids read off the
    # SM's denormalized columns. See gitlab-org/gitlab#600290.

    context 'and the secrets manager is active' do
      let!(:secrets_manager) { create(:group_secrets_manager, :active, group: group) }

      it 'lets CASCADE + the trigger enqueue the deprovision task; no service call' do
        expect(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService).not_to receive(:new)

        expect { subject.execute }
          .to change { SecretsManagement::GroupSecretsManager.where(group_id: group.id).count }.from(1).to(0)
          .and change {
                 SecretsManagement::GroupSecretsManagerMaintenanceTask.where(group_id: group.id,
                   action: :deprovision).count
               }.from(0).to(1)
      end
    end

    context 'and the secrets manager is still provisioning' do
      let!(:secrets_manager) { create(:group_secrets_manager, :provisioning, group: group) }

      it 'still cascade-deletes the SM and creates a deprovision task' do
        expect(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService).not_to receive(:new)

        expect { subject.execute }
          .to change { SecretsManagement::GroupSecretsManager.where(group_id: group.id).count }.from(1).to(0)
          .and change {
                 SecretsManagement::GroupSecretsManagerMaintenanceTask.where(group_id: group.id,
                   action: :deprovision).count
               }.from(0).to(1)

        expect(Group.find_by(id: group.id)).to be_nil
      end
    end

    context 'and a deprovision maintenance task already exists' do
      let!(:secrets_manager) { create(:group_secrets_manager, :active, group: group) }
      let!(:existing_task) do
        create(:group_secrets_manager_maintenance_task, :deprovision, group: group, user: user)
      end

      it "the trigger's ON CONFLICT skips the dup; the existing task drains as usual" do
        expect(SecretsManagement::DeprovisionGroupSecretsManagerWorker).not_to receive(:perform_async)

        expect { subject.execute }
          .to change { SecretsManagement::GroupSecretsManager.where(group_id: group.id).count }.from(1).to(0)
          .and not_change { SecretsManagement::GroupSecretsManagerMaintenanceTask.where(group_id: group.id, action: :deprovision).count }
      end
    end
  end

  context 'when group has no secrets manager' do
    it 'completes the destroy without touching SM state' do
      expect(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService).not_to receive(:new)

      expect { subject.execute }
        .to not_change { SecretsManagement::GroupSecretsManagerMaintenanceTask.count }
    end

    context 'but a descendant subgroup has a secrets manager' do
      # The descendant's own destroy CASCADE-deletes its SM and fires
      # its own trigger. We assert that hand-off still happens even
      # when there's nothing to do at the parent.
      let!(:subgroup) { create(:group, parent: group) }
      let!(:subgroup_sm) { create(:group_secrets_manager, :active, group: subgroup) }

      it 'creates a deprovision task for the descendant SM via the trigger' do
        expect { subject.execute }
          .to change {
                SecretsManagement::GroupSecretsManagerMaintenanceTask.where(group_id: subgroup.id,
                  action: :deprovision).count
              }.from(0).to(1)
      end
    end

    context 'but a descendant project has a secrets manager' do
      let!(:descendant_project) { create(:project, namespace: group) }
      let!(:project_sm) { create(:project_secrets_manager, :active, project: descendant_project) }

      it 'creates a deprovision task for the descendant project SM via the trigger' do
        expect { subject.execute }
          .to change {
                SecretsManagement::ProjectSecretsManagerMaintenanceTask.where(project_id: descendant_project.id,
                  action: :deprovision).count
              }.from(0).to(1)
      end
    end
  end
end
