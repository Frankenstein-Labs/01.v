# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::LicenseType, feature_category: :dependency_management do
  include GraphqlHelpers

  let(:fields) { %i[name url spdxIdentifier policy_violations] }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe '#policy_violations' do
    let_it_be(:project) { create(:project) }
    let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let_it_be(:security_policy) { create(:security_policy, name: 'Test Policy') }

    let(:license_hash) do
      {
        'name' => 'MIT License',
        'spdx_identifier' => 'MIT',
        'url' => 'https://opensource.org/licenses/MIT',
        'occurrence_uuid' => occurrence.uuid,
        'project_id' => project.id
      }
    end

    let(:license_type) do
      described_class.authorized_new(license_hash, query_context(user: User.new))
    end

    context 'when policy dismissals exist for the license' do
      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid],
          licenses: { 'MIT License' => ['MIT'] },
          status: :preserved)
      end

      it 'returns a BatchLoader instance' do
        expect(license_type.policy_violations).to be_a(BatchLoader::GraphQL)
      end

      it 'loads the policy dismissals for the license' do
        result = license_type.policy_violations.sync

        expect(result).to contain_exactly(policy_dismissal)
      end
    end

    context 'when policy dismissal does not specify licenses' do
      let_it_be(:policy_dismissal_all_licenses) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid],
          licenses: {},
          status: :preserved)
      end

      it 'does not include the dismissal' do
        result = license_type.policy_violations.sync

        expect(result).to be_empty
      end
    end

    context 'when policy dismissal is for a different license' do
      let_it_be(:policy_dismissal_other_license) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid],
          licenses: { 'Apache License 2.0' => ['Apache-2.0'] },
          status: :preserved)
      end

      it 'does not include the dismissal' do
        result = license_type.policy_violations.sync

        expect(result).to be_empty
      end
    end

    context 'when policy dismissal is not preserved' do
      let_it_be(:open_policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid],
          licenses: { 'MIT License' => ['MIT'] },
          status: :open)
      end

      it 'does not include the dismissal' do
        result = license_type.policy_violations.sync

        expect(result).to be_empty
      end
    end

    context 'when occurrence_uuid and project is not present' do
      let(:license_hash_without_occurrence_uuid_and_project) do
        {
          'name' => 'MIT License',
          'spdx_identifier' => 'MIT',
          'url' => 'https://opensource.org/licenses/MIT'
        }
      end

      let(:license_type_without_occurrence_uuid_and_project) do
        described_class.authorized_new(license_hash_without_occurrence_uuid_and_project, query_context(user: User.new))
      end

      it 'returns an empty array' do
        expect(license_type_without_occurrence_uuid_and_project.policy_violations).to eq([])
      end
    end

    context 'when name is not present' do
      let(:license_hash_without_name) do
        {
          'spdx_identifier' => 'MIT',
          'url' => 'https://example.com/license',
          occurrence: occurrence
        }
      end

      let(:license_type_without_name) do
        described_class.authorized_new(license_hash_without_name, query_context(user: User.new))
      end

      it 'returns an empty array' do
        expect(license_type_without_name.policy_violations).to eq([])
      end
    end

    context 'when name is blank' do
      let_it_be(:policy_dismissal_with_licenses) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid],
          licenses: { 'MIT License' => ['MIT'] },
          status: :preserved)
      end

      let(:license_hash_with_blank_name) do
        {
          'name' => '',
          'spdx_identifier' => 'MIT',
          'url' => 'https://opensource.org/licenses/MIT',
          'occurrence_uuid' => occurrence.uuid,
          'project_id' => project.id
        }
      end

      let(:license_type_with_blank_name) do
        described_class.authorized_new(license_hash_with_blank_name, query_context(user: User.new))
      end

      it 'does not include the dismissal' do
        result = license_type_with_blank_name.policy_violations.sync

        expect(result).to be_empty
      end
    end
  end
end
