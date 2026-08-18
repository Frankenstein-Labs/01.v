# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillLicensesOutsideSpdx, feature_category: :security_policy_management do
  let(:custom_software_licenses) { table(:custom_software_licenses) }
  let(:software_license_policies) { table(:software_license_policies) }
  let(:organizations) { table(:organizations) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:scan_result_policies) { table(:scan_result_policies) }
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let!(:namespace) { namespaces.create!(name: 'namespace', path: 'namespace', organization_id: organization.id) }
  let!(:project) do
    projects.create!(namespace_id: namespace.id, project_namespace_id: namespace.id, organization_id: organization.id)
  end

  subject(:perform_migration) do
    described_class.new(
      start_id: software_license_policies.minimum(:id),
      end_id: software_license_policies.maximum(:id),
      batch_table: :software_license_policies,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 2.minutes,
      connection: ApplicationRecord.connection
    ).perform
  end

  shared_examples_for 'does not creates a new custom software license' do
    specify do
      expect { perform_migration }.not_to change { custom_software_licenses.count }
    end
  end

  context 'when there are no software license policies with non-spdx software license_spdx_identifier' do
    let!(:software_license_policy) do
      software_license_policies.create!(project_id: project.id,
        software_license_spdx_identifier: 'MIT',
        custom_software_license_id: nil)
    end

    it_behaves_like 'does not creates a new custom software license'

    it 'does not sets a custom_software_license_id' do
      expect { perform_migration }.not_to change { software_license_policy.reload.custom_software_license_id }
    end

    it 'does not removes the software_license_spdx_identifier' do
      expect { perform_migration }.not_to change { software_license_policy.reload.software_license_spdx_identifier }
    end
  end

  context 'when there are software license policies with non-spdx software license_spdx_identifiers' do
    let(:non_spdx_identifier) { 'non_spdx_software_license_spdx_identifier' }
    let!(:namespace_policy_project) do
      namespaces.create!(name: 'namespace policy', path: 'namespace policy', organization_id: organization.id)
    end

    let!(:policy_project) do
      projects.create!(namespace_id: namespace.id, project_namespace_id: namespace_policy_project.id,
        organization_id: organization.id)
    end

    let!(:security_policy_config) do
      security_orchestration_policy_configurations.create!(
        security_policy_management_project_id: policy_project.id,
        project_id: project.id
      )
    end

    let!(:scan_result_policy) do
      scan_result_policies.create!(
        project_id: project.id,
        security_orchestration_policy_configuration_id: security_policy_config.id,
        orchestration_policy_idx: 0,
        rule_idx: 0
      )
    end

    let!(:software_license_policy) do
      software_license_policies.create!(project_id: project.id,
        software_license_spdx_identifier: non_spdx_identifier,
        custom_software_license_id: nil,
        scan_result_policy_id: scan_result_policy.id)
    end

    shared_examples_for 'creates a new custom software license' do
      specify do
        expect { perform_migration }.to change { custom_software_licenses.count }.by(1)
      end
    end

    shared_examples_for 'sets the custom_software_license_id' do
      specify do
        expect(software_license_policy.custom_software_license_id).to be_nil

        perform_migration

        custom_software_license = custom_software_licenses.last

        expect(software_license_policy.reload.custom_software_license_id).to eq(custom_software_license.id)
      end
    end

    shared_examples_for 'sets the software_license_spdx_identifier to nil' do
      specify do
        expect(software_license_policy.software_license_spdx_identifier).to eq(non_spdx_identifier)

        perform_migration

        expect(software_license_policy.reload.software_license_spdx_identifier).to be_nil
      end
    end

    context 'when a custom_software_license with the software_license name does not exist' do
      it_behaves_like 'creates a new custom software license'
      it_behaves_like 'sets the custom_software_license_id'
      it_behaves_like 'sets the software_license_spdx_identifier to nil'

      context 'when multiple software_license_policies have the same software_license_spdx_identifier' do
        let!(:software_license_policy_same_spdx) do
          software_license_policies.create!(project_id: project.id,
            software_license_spdx_identifier: non_spdx_identifier,
            custom_software_license_id: nil,
            scan_result_policy_id: scan_result_policy.id)
        end

        it_behaves_like 'creates a new custom software license'

        it 'does not raise ActiveRecord::RecordNotUnique' do
          expect { perform_migration }.not_to raise_error
        end

        it 'updates one record and skip the duplicated ones' do
          expect(software_license_policy.software_license_spdx_identifier).to eq(non_spdx_identifier)
          expect(software_license_policy_same_spdx.software_license_spdx_identifier).to eq(non_spdx_identifier)

          perform_migration

          expect(software_license_policy.reload.software_license_spdx_identifier).to be_nil
          expect(software_license_policy_same_spdx.reload.software_license_spdx_identifier).to eq(non_spdx_identifier)
        end
      end
    end

    context 'when a custom_software_license with the software_license name exist' do
      let!(:custom_software_license) do
        custom_software_licenses.create!(name: non_spdx_identifier, project_id: project_id)
      end

      context 'when the custom_software_license is associated to another project' do
        let!(:other_organization) { organizations.create!(name: 'other organization', path: 'other organization') }
        let!(:other_namespace) do
          namespaces.create!(name: 'other namespace', path: 'other namespace', organization_id: organization.id)
        end

        let!(:other_project) do
          projects.create!(namespace_id: other_namespace.id, project_namespace_id: other_namespace.id,
            organization_id: other_organization.id)
        end

        let(:project_id) { other_project.id }

        it_behaves_like 'creates a new custom software license'
        it_behaves_like 'sets the custom_software_license_id'
        it_behaves_like 'sets the software_license_spdx_identifier to nil'
      end

      context 'when the custom_software_license is associated to the same project' do
        let(:project_id) { project.id }

        it_behaves_like 'does not creates a new custom software license'
        it_behaves_like 'sets the custom_software_license_id'
        it_behaves_like 'sets the software_license_spdx_identifier to nil'
      end
    end
  end
end
