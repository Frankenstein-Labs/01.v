# frozen_string_literal: true

require 'spec_helper'

# -- We need extra helpers to define tables
RSpec.describe Gitlab::BackgroundMigration::BackfillComplianceFrameworkSecurityPolicyId, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:security_policies) { table(:security_policies) }
  let(:compliance_framework_security_policies) { table(:compliance_framework_security_policies) }
  let(:compliance_frameworks) { table(:compliance_management_frameworks) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:organizations) { table(:organizations) }

  let(:args) do
    min, max = compliance_framework_security_policies.pick('MIN(id)', 'MAX(id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'compliance_framework_security_policies',
      batch_column: 'id',
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }

  let!(:group_namespace) do
    namespaces.create!(
      organization_id: organization.id,
      name: 'gitlab-org',
      path: 'gitlab-org',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:framework) do
    compliance_frameworks.create!(
      namespace_id: group_namespace.id,
      name: 'Framework',
      color: '#000000',
      description: 'Test Framework'
    )
  end

  let!(:other_framework) do
    compliance_frameworks.create!(
      namespace_id: group_namespace.id,
      name: 'Other Framework',
      color: '#000000',
      description: 'Other Test Framework'
    )
  end

  let!(:policy_project) { create_project('policy_project', group_namespace) }

  let!(:policy_configuration) do
    security_orchestration_policy_configurations.create!(
      namespace_id: group_namespace.id,
      security_policy_management_project_id: policy_project.id
    )
  end

  let!(:security_policy_with_framework) do
    security_policies.create!(
      type: 0,
      policy_index: 0,
      name: 'Policy with Framework',
      description: 'Test Policy',
      enabled: true,
      checksum: '0000000000000000000000000000000000000000000000000000000000000000',
      scope: { compliance_frameworks: [{ id: framework.id }] },
      content: {},
      security_policy_management_project_id: policy_project.id,
      security_orchestration_policy_configuration_id: policy_configuration.id
    )
  end

  let!(:security_policy_with_other_framework) do
    security_policies.create!(
      type: 0,
      policy_index: 1,
      name: 'Policy without Framework',
      description: 'Test Policy',
      enabled: true,
      checksum: '0000000000000000000000000000000000000000000000000000000000000000',
      scope: { compliance_frameworks: [{ id: other_framework.id }] },
      content: {},
      security_policy_management_project_id: policy_project.id,
      security_orchestration_policy_configuration_id: policy_configuration.id
    )
  end

  let!(:security_policy_without_framework) do
    security_policies.create!(
      type: 0,
      policy_index: 2,
      name: 'Policy without Framework',
      description: 'Test Policy',
      enabled: true,
      checksum: '0000000000000000000000000000000000000000000000000000000000000000',
      scope: {},
      content: {},
      security_policy_management_project_id: policy_project.id,
      security_orchestration_policy_configuration_id: policy_configuration.id
    )
  end

  let!(:compliance_framework_security_policy) do
    compliance_framework_security_policies.create!(
      framework_id: framework.id,
      policy_configuration_id: policy_configuration.id,
      security_policy_id: nil,
      policy_index: 0
    )
  end

  let!(:other_compliance_framework_security_policy) do
    compliance_framework_security_policies.create!(
      framework_id: other_framework.id,
      policy_configuration_id: policy_configuration.id,
      security_policy_id: nil,
      policy_index: 2
    )
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  describe '#perform' do
    it 'creates compliance framework security policies and deletes rows without security_policy_id' do
      perform_migration

      framework_policies = compliance_framework_security_policies.where(framework_id: framework.id)
      expect(framework_policies.map(&:security_policy_id)).to eq([security_policy_with_framework.id])

      expect(
        compliance_framework_security_policies.where(
          framework_id: framework.id,
          policy_configuration_id: policy_configuration.id,
          security_policy_id: nil
        ).count
      ).to eq(0)
    end

    context 'when there are multiple matching security policies' do
      let!(:another_security_policy_with_framework) do
        security_policies.create!(
          type: 0,
          policy_index: 3,
          name: 'Another Policy with Framework',
          description: 'Test Policy',
          enabled: true,
          checksum: '0000000000000000000000000000000000000000000000000000000000000000',
          scope: { compliance_frameworks: [{ id: framework.id }] },
          content: {},
          security_policy_management_project_id: policy_project.id,
          security_orchestration_policy_configuration_id: policy_configuration.id
        )
      end

      it 'creates links for all matching security policies' do
        expect { perform_migration }.to change { compliance_framework_security_policies.count }.by(1)

        framework_policies = compliance_framework_security_policies.where(framework_id: framework.id)
        expect(framework_policies.map(&:security_policy_id)).to contain_exactly(
          security_policy_with_framework.id,
          another_security_policy_with_framework.id
        )
      end
    end

    context 'when security policy has multiple frameworks in scope' do
      let!(:security_policy_with_multiple_frameworks) do
        security_policies.create!(
          type: 0,
          policy_index: 3,
          name: 'Policy with Multiple Frameworks',
          description: 'Test Policy',
          enabled: true,
          checksum: '0000000000000000000000000000000000000000000000000000000000000000',
          scope: {
            compliance_frameworks: [
              { id: framework.id },
              { id: other_framework.id }
            ]
          },
          content: {},
          security_policy_management_project_id: policy_project.id,
          security_orchestration_policy_configuration_id: policy_configuration.id
        )
      end

      it 'creates links for each matching framework' do
        perform_migration

        expect(compliance_framework_security_policies.where(
          security_policy_id: security_policy_with_multiple_frameworks.id
        ).pluck(:framework_id)).to contain_exactly(framework.id, other_framework.id)
      end
    end

    context 'when compliance framework security policy already has a security policy' do
      let!(:existing_compliance_framework_security_policy) do
        compliance_framework_security_policies.create!(
          framework_id: framework.id,
          policy_configuration_id: policy_configuration.id,
          policy_index: 4,
          security_policy_id: security_policies.create!(
            type: 0,
            policy_index: 4,
            name: 'Existing Policy',
            description: 'Test Policy',
            enabled: true,
            checksum: '0000000000000000000000000000000000000000000000000000000000000000',
            scope: {},
            content: {},
            security_policy_management_project_id: policy_project.id,
            security_orchestration_policy_configuration_id: policy_configuration.id
          ).id
        )
      end

      it 'does not modify existing links' do
        original_security_policy_id = existing_compliance_framework_security_policy.security_policy_id
        perform_migration

        expect(existing_compliance_framework_security_policy.reload.security_policy_id)
          .to eq(original_security_policy_id)
      end
    end
  end

  def create_project(name, group)
    project_namespace = namespaces.create!(
      name: name,
      path: name,
      type: 'Project',
      organization_id: group.organization_id
    )

    table(:projects).create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name
    )
  end
end
