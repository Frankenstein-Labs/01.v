# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::VulnerabilitiesPipeline, feature_category: :importers do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, group: group) }
  let(:bulk_import) { create(:bulk_import, user: user) }
  let(:entity) do
    create(
      :bulk_import_entity,
      :project_entity,
      project: project,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_slug: 'My-Destination-Project',
      destination_namespace: group.full_path
    )
  end

  let(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let(:context) { BulkImports::Pipeline::Context.new(tracker) }

  let(:exported_vulnerability) do
    {
      "project_id" => project.id,
      "author_id" => user.id,
      "title" => "Regular expression with non-literal value",
      "description" => nil,
      "severity" => "medium",
      "report_type" => "sast",
      "vulnerability_finding" => {
        "severity" => "medium",
        "report_type" => "sast",
        "project_id" => project.id,
        "location_fingerprint" => "4f7a2fffbb791c4cc8d1454db40b80f7fa9ed5be",
        "name" => "Regular expression with non-literal value",
        "metadata_version" => "15.1.4",
        "raw_metadata" => Gitlab::Json.dump({
          id: "b13b66b99eabefb8bc0d385b90cb952734e246ff3477a8ee563d6d04ef4bded4",
          category: "sast",
          name: "Regular expression with non-literal value",
          description: "The `RegExp` constructor was called with a non-literal value...", # truncated for brevity
          cve: "semgrep_id:eslint.detect-non-literal-regexp:515:515",
          severity: "Medium",
          scanner: {
            id: "semgrep",
            name: "Semgrep"
          }
        }),
        "detection_method" => "gitlab_security_report",
        "scanner" => {
          "project_id" => project.id,
          "external_id" => "semgrep",
          "name" => "Semgrep",
          "vendor" => "GitLab"
        },
        "primary_identifier" => {
          "project_id" => project.id,
          "fingerprint" => "a751f35f1185de7ca5e6c0610c3bca21eb25ac9a",
          "external_type" => "semgrep_id",
          "external_id" => "eslint.detect-non-literal-regexp",
          "name" => "eslint.detect-non-literal-regexp",
          "url" => "https://semgrep.dev/r/gitlab.eslint.detect-non-literal-regexp"
        }
      }
    }
  end

  let(:exported_vulnerability2) do
    {
      "project_id" => project.id,
      "author_id" => user.id,
      "title" => "Unsafe Deserialization of User Input",
      "description" => "Application deserializes untrusted user input without validation",
      "severity" => "high",
      "report_type" => "sast",
      "vulnerability_finding" => {
        "severity" => "high",
        "report_type" => "sast",
        "project_id" => project.id,
        "location_fingerprint" => "7bc8a2d5e4f3c6b9a0d1e8f7c4b3a2d5",
        "name" => "Unsafe Deserialization of User Input",
        "metadata_version" => "15.1.4",
        "raw_metadata" => Gitlab::Json.dump({
          id: "c24d77aa8b95ef6c91d3b8f7e9a4c6b3d2e1f0a9",
          category: "sast",
          name: "Unsafe Deserialization of User Input",
          description: "The application deserializes untrusted user input without proper validation, ...",
          cve: "semgrep_id:ruby.lang.security.deserialization.unsafe-deserialization",
          severity: "High",
          scanner: {
            id: "semgrep",
            name: "Semgrep"
          }
        }),
        "detection_method" => "gitlab_security_report",
        "scanner" => {
          "project_id" => project.id,
          "external_id" => "semgrep",
          "name" => "Semgrep",
          "vendor" => "GitLab"
        },
        "primary_identifier" => {
          "project_id" => project.id,
          "fingerprint" => "b862f46g2296ef8db6f7d1c724cd3b32fc36bd9b",
          "external_type" => "semgrep_id",
          "external_id" => "ruby.lang.security.deserialization.unsafe-deserialization",
          "name" => "ruby.lang.security.deserialization.unsafe-deserialization",
          "url" => "https://semgrep.dev/r/ruby.lang.security.deserialization.unsafe-deserialization"
        }
      }
    }
  end

  let(:pipeline) { described_class.new(context) }

  before do
    group.add_owner(user)

    allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
      allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [
        exported_vulnerability.deep_dup,
        exported_vulnerability2.deep_dup
      ]))
    end

    allow(pipeline).to receive(:set_source_objects_counter)
  end

  describe '#run' do
    it 'imports vulnerability with its findings into destination project' do
      expect { pipeline.run }.to change { Vulnerability.count }.by(2)
        .and change { Vulnerabilities::Finding.count }.by(2)

      imported_vulnerability = project.vulnerabilities.find_by!(title: exported_vulnerability['title'])
      imported_finding = imported_vulnerability.vulnerability_finding

      expect(imported_vulnerability.title).to eq(exported_vulnerability['title'])
      expect(imported_vulnerability.description).to eq(exported_vulnerability['description'])
      expect(imported_vulnerability.severity).to eq(exported_vulnerability['severity'])
      expect(imported_vulnerability.report_type).to eq(exported_vulnerability['report_type'])

      expect(imported_finding.uuid).not_to be_empty
      expect(imported_finding.uuid).not_to eq('00000000-0000-0000-0000-000000000000')
      expect(imported_finding.name).to eq(exported_vulnerability['vulnerability_finding']['name'])
      expect(imported_finding.severity).to eq(exported_vulnerability['vulnerability_finding']['severity'])
      expect(imported_finding.detection_method)
      .to eq(exported_vulnerability['vulnerability_finding']['detection_method'])
      expect(imported_finding.scanner.name).to eq(exported_vulnerability['vulnerability_finding']['scanner']['name'])
      expect(imported_finding.primary_identifier.external_id)
        .to eq(exported_vulnerability['vulnerability_finding']['primary_identifier']['external_id'])

      expect(project.vulnerabilities.count).to eq(2)

      imported_vulnerability2 = project.vulnerabilities.find_by!(title: exported_vulnerability2['title'])
      imported_finding2 = imported_vulnerability2.vulnerability_finding

      expect(imported_vulnerability2.title).to eq(exported_vulnerability2['title'])
      expect(imported_vulnerability2.description).to eq(exported_vulnerability2['description'])
      expect(imported_vulnerability2.severity).to eq(exported_vulnerability2['severity'])
      expect(imported_vulnerability2.report_type).to eq(exported_vulnerability2['report_type'])

      expect(imported_finding2.uuid).not_to be_empty
      expect(imported_finding2.uuid).not_to eq('00000000-0000-0000-0000-000000000000')
      expect(imported_finding2.location_fingerprint)
      .to eq(exported_vulnerability2['vulnerability_finding']['location_fingerprint'])
      expect(imported_finding2.name).to eq(exported_vulnerability2['vulnerability_finding']['name'])
      expect(imported_finding2.severity).to eq(exported_vulnerability2['vulnerability_finding']['severity'])
      expect(imported_finding2.detection_method)
      .to eq(exported_vulnerability2['vulnerability_finding']['detection_method'])
      expect(imported_finding2.scanner.name).to eq(exported_vulnerability2['vulnerability_finding']['scanner']['name'])
      expect(imported_finding2.primary_identifier.external_id)
        .to eq(exported_vulnerability2['vulnerability_finding']['primary_identifier']['external_id'])
    end
  end

  describe '#load' do
    context 'when vulnerability is not persisted' do
      it 'saves the vulnerability' do
        vulnerability = build(:vulnerability, project: project)

        expect(vulnerability).to receive(:save!)

        pipeline.load(context, vulnerability)
      end
    end

    context 'when vulnerability is missing' do
      it 'returns' do
        expect(pipeline.load(context, nil)).to be_nil
      end
    end
  end
end
