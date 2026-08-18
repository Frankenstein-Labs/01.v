# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::SyncScanResultPolicies, feature_category: :security_policy_management do
  describe '#perform' do
    let(:batch_table) { :security_orchestration_policy_configurations }
    let(:batch_column) { :id }
    let(:sub_batch_size) { 1 }
    let(:pause_ms) { 0 }
    let(:connection) { ApplicationRecord.connection }

    let(:projects) { table(:projects) }
    let(:namespaces) { table(:namespaces) }
    let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }

    let(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }

    let(:group_namespace) do
      namespaces.create!(name: 'group_1', path: 'group_1', type: 'Group',
        organization_id: organization.id).tap do |group|
        group.update!(traversal_ids: [group.id])
      end
    end

    # rubocop:disable Layout/LineLength -- easier to read in single line
    let(:project_namespace_1) { namespaces.create!(name: '1', path: '1', type: 'Project', parent_id: group_namespace, organization_id: organization.id) }
    let(:project_namespace_2) { namespaces.create!(name: '2', path: '2', type: 'Project', parent_id: group_namespace, organization_id: organization.id) }
    let(:project_namespace_3) { namespaces.create!(name: '3', path: '3', type: 'Project', parent_id: group_namespace, organization_id: organization.id) }

    let(:project_1) { projects.create!(namespace_id: group_namespace.id, project_namespace_id: project_namespace_1.id, organization_id: organization.id) }
    let(:project_2) { projects.create!(namespace_id: group_namespace.id, project_namespace_id: project_namespace_2.id, organization_id: organization.id) }
    let(:project_3) { projects.create!(namespace_id: group_namespace.id, project_namespace_id: project_namespace_3.id, organization_id: organization.id) }
    # rubocop:enable Layout/LineLength

    let(:policy_project_namespace) do
      namespaces.create!(name: '4', path: '4', type: 'Project', organization_id: organization.id)
    end

    let(:policy_project) do
      projects.create!(
        name: 'Policy Project',
        namespace_id: policy_project_namespace.id,
        project_namespace_id: policy_project_namespace.id,
        organization_id: organization.id
      )
    end

    let(:project_policy_configuration) { create_policy_configuration(project_id: project_1.id) }
    let(:project_policy_configuration_2) { create_policy_configuration(project_id: project_2.id) }
    let(:namespace_policy_configuration) { create_policy_configuration(namespace_id: group_namespace.id) }

    subject(:perform) do
      described_class.new(
        start_id: project_policy_configuration.id,
        end_id: namespace_policy_configuration.id,
        batch_table: batch_table,
        batch_column: batch_column,
        sub_batch_size: sub_batch_size,
        pause_ms: pause_ms,
        connection: connection
      ).perform
    end

    it 'enqueues Security::SyncScanPoliciesWorker for each project of policy configuration' do
      expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(project_policy_configuration.id)
      expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(project_policy_configuration_2.id)
      expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(namespace_policy_configuration.id)

      perform
    end

    def create_policy_configuration(project_id: nil, namespace_id: nil)
      security_orchestration_policy_configurations.create!(
        project_id: project_id,
        namespace_id: namespace_id,
        security_policy_management_project_id: policy_project.id
      )
    end
  end
end
