# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Sbom::Exporters::Cyclonedx::V16JsonService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:export, freeze: false) { create(:dependency_list_export, project: project) }
  let_it_be(:sbom_occurrences, freeze: false) { project.sbom_occurrences }
  let_it_be(:record_with_purl_type) { create(:sbom_occurrence, :bundler, project: project) }
  let_it_be(:record_with_mit_license) { create(:sbom_occurrence, :mit, project: project) }
  let_it_be(:record_without_spdx_id) { create(:sbom_occurrence, :license_without_spdx_id, project: project) }
  let_it_be(:record_with_unknown_license) { create(:sbom_occurrence, :unknown, project: project) }
  let_it_be(:record_with_no_purl_type) do
    component = create(:sbom_component, purl_type: nil)
    create(:sbom_occurrence, component: component, project: project)
  end

  let_it_be(:component_in_multiple_locations) { create(:sbom_occurrence, :bundler, project: project) }
  let_it_be(:other_location) do
    create(:sbom_occurrence,
      :bundler,
      component: component_in_multiple_locations.component,
      component_version: component_in_multiple_locations.component_version,
      project: project
    )
  end

  let(:generate) { described_class.new(export, sbom_occurrences).generate }

  subject(:output) { Gitlab::Json.parse(generate) }

  def find_component(occurrence)
    output['components'].find { |component| component['name'] == occurrence.name }
  end

  describe 'schema' do
    let(:schema) { JSONSchemer.schema(Pathname.new('ee/app/validators/json_schemas/cyclonedx/bom-1.6.schema.json')) }
    let(:errors) { schema.validate(output).map { |e| JSONSchemer::Errors.pretty(e) } }

    it 'conforms to specification version 1.6' do
      expect(errors).to be_empty
    end
  end

  describe 'output' do
    it 'sets version to 1' do
      expect(output['version']).to eq(1)
    end

    it 'has correct metadata' do
      expect(output['metadata']).to match({
        "timestamp" => match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z/),
        "tools" => [
          {
            "vendor" => "GitLab",
            "name" => "GitLab dependency list export",
            "version" => Gitlab::VERSION
          }
        ],
        "manufacturer" => {
          "name" => "GitLab",
          "url" => ["https://about.gitlab.com/"],
          "contact" => [{
            "name" => "GitLab Support",
            "email" => "support@gitlab.com"
          }]
        },
        "component" => {
          "type" => "application",
          "name" => project.name,
          "externalReferences" => [{ "type" => "vcs", "url" => project.http_url_to_repo }]
        }
      })
    end

    it 'uses spdx identifier for the license id' do
      license_id = find_component(record_with_mit_license).dig('licenses', 0, 'license', 'id')
      expect(license_id).to eq('MIT')
    end

    it 'uses name if there is no spdx identifier' do
      license_name = find_component(record_without_spdx_id).dig('licenses', 0, 'license', 'name')
      expect(license_name).to eq('Custom License')
    end

    it 'removes unknown licenses' do
      expect(find_component(record_with_unknown_license)['licenses']).to be_empty
    end

    context 'when license overrides are active' do
      let(:override_license_name) { 'MIT License' }
      let(:purl_string) { record_with_unknown_license.purl.to_s }

      let!(:approval_policy_rule) do
        rule = create(:approval_policy_rule, :license_finding_with_allowed_licenses,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: %w[newly_detected],
            licenses: { allowed: [{ name: override_license_name }] },
            license_overrides: [{ purl: purl_string, license: override_license_name, mode: 'patch' }]
          })
        create(:approval_policy_rule_project_link, approval_policy_rule: rule, project: project)
        rule
      end

      before do
        allow_next_instance_of(Security::LicenseOverrideApplicator) do |applicator|
          allow(applicator).to receive(:experiment_enabled_for_project?).and_return(true)
        end
      end

      it 'replaces unknown license with overridden license in CycloneDX export' do
        component = find_component(record_with_unknown_license)

        expect(component['licenses']).not_to be_empty
        # The SPDX ID is resolved from the display name: "MIT License" -> "MIT"
        expect(component.dig('licenses', 0, 'license', 'id')).to eq('MIT')
      end
    end

    context 'when license override uses a custom (non-SPDX) license' do
      let(:custom_license_name) { 'LicenseRef-Acme-Innersource' }
      let(:purl_string) { record_with_unknown_license.purl.to_s }

      let!(:approval_policy_rule) do
        rule = create(:approval_policy_rule, :license_finding_with_allowed_licenses,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: %w[newly_detected],
            licenses: { allowed: [{ name: custom_license_name }] },
            license_overrides: [{ purl: purl_string, license: custom_license_name, mode: 'patch' }]
          })
        create(:approval_policy_rule_project_link, approval_policy_rule: rule, project: project)
        rule
      end

      before do
        allow_next_instance_of(Security::LicenseOverrideApplicator) do |applicator|
          allow(applicator).to receive(:experiment_enabled_for_project?).and_return(true)
        end
      end

      it 'uses name field instead of id for custom licenses per CycloneDX spec' do
        component = find_component(record_with_unknown_license)

        expect(component['licenses']).not_to be_empty
        license_entry = component.dig('licenses', 0, 'license')
        # Custom licenses must NOT use 'id' (reserved for SPDX identifiers)
        expect(license_entry).not_to have_key('id')
        expect(license_entry['name']).to eq(custom_license_name)
      end
    end

    it 'removes duplicates if same component exists in multiple locations' do
      deduplicated_component = output['components'].select do |component|
        component['name'] == component_in_multiple_locations.component_name
      end

      expect(deduplicated_component.size).to eq(1)
      expect(deduplicated_component.first).to eq({
        'name' => component_in_multiple_locations.name,
        'version' => component_in_multiple_locations.version,
        'type' => 'library',
        'bom-ref' => component_in_multiple_locations.purl.to_s,
        'licenses' => [],
        'purl' => component_in_multiple_locations.purl.to_s
      })
    end

    it 'sorts components by bom-ref' do
      expect(output['components']).to be_sorted.by { |component| component['bom-ref'] }
    end

    it 'uses uuid as bom-ref if there is no purl_type' do
      expect(find_component(record_with_no_purl_type)['bom-ref']).to start_with('urn:uuid:')
    end

    it 'uses purl as bom-ref when there is a purl_type' do
      expect(find_component(record_with_purl_type)['bom-ref']).to start_with('pkg:')
    end

    it 'does not cause N+1 queries' do
      control = ActiveRecord::QueryRecorder.new { described_class.new(export, sbom_occurrences).generate }

      create(:sbom_occurrence, :yarn, project: project)
      create(:sbom_occurrence, :nuget, project: project)

      expect { described_class.new(export, sbom_occurrences).generate }.not_to exceed_query_limit(control)
    end
  end
end
