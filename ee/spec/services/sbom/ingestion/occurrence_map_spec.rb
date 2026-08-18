# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::OccurrenceMap, feature_category: :dependency_management do
  let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, source_package_name: 'source-package-name') }
  let_it_be(:report_source) { build_stubbed(:ci_reports_sbom_source) }

  let(:base_data) do
    {
      component_id: nil,
      component_type: report_component.component_type,
      component_version_id: nil,
      name: report_component.name,
      purl_type: report_component.purl.type,
      source: report_source.data,
      source_id: nil,
      source_type: report_source.source_type,
      uuid: nil,
      source_package_id: nil,
      source_package_name: report_component.source_package_name,
      sbom_occurrence_id: nil,
      security_project_tracked_context_id: nil,
      version: report_component.version
    }
  end

  subject(:occurrence_map) { described_class.new(report_component, report_source) }

  describe '#to_h' do
    it 'returns a hash with base data without ids assigned' do
      expect(occurrence_map.to_h).to eq(base_data)
    end

    context 'when ids are assigned' do
      let(:ids) do
        {
          component_id: 1,
          component_version_id: 2,
          source_id: 3,
          source_package_id: 4
        }
      end

      before do
        occurrence_map.component_id = ids[:component_id]
        occurrence_map.component_version_id = ids[:component_version_id]
        occurrence_map.source_id = ids[:source_id]
        occurrence_map.source_package_id = ids[:source_package_id]
      end

      it 'returns a hash with ids and base data' do
        expect(occurrence_map.to_h).to eq(base_data.merge(ids))
      end
    end

    context 'when there is no source' do
      let(:report_source) { nil }

      it 'returns a hash without source information' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            purl_type: report_component.purl.type,
            name: report_component.name,
            source: nil,
            source_id: nil,
            source_type: nil,
            uuid: nil,
            source_package_id: nil,
            source_package_name: report_component.source_package_name,
            sbom_occurrence_id: nil,
            security_project_tracked_context_id: nil,
            version: report_component.version
          }
        )
      end
    end

    context 'when component has no purl' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, purl: nil) }

      it 'returns a hash with a nil purl_type' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            name: report_component.name,
            purl_type: nil,
            source: report_source.data,
            source_id: nil,
            source_type: report_source.source_type,
            uuid: nil,
            source_package_id: nil,
            source_package_name: report_component.source_package_name,
            sbom_occurrence_id: nil,
            security_project_tracked_context_id: nil,
            version: report_component.version
          }
        )
      end
    end

    context 'when component has namespace' do
      let_it_be(:report_component) do
        build_stubbed(:ci_reports_sbom_component, namespace: 'org.apache.tomcat',
          name: 'tomcat-catalina', purl_type: 'maven')
      end

      it 'returns a hash with name attribute having both namespace and name' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            name: 'org.apache.tomcat/tomcat-catalina',
            purl_type: 'maven',
            source: report_source.data,
            source_id: nil,
            source_type: report_source.source_type,
            uuid: nil,
            source_package_id: nil,
            source_package_name: report_component.source_package_name,
            sbom_occurrence_id: nil,
            security_project_tracked_context_id: nil,
            version: report_component.version
          }
        )
      end
    end

    context 'when occurrence_id and tracked context are set' do
      let_it_be(:tracked_context) { build_stubbed(:security_project_tracked_context) }

      subject(:occurrence_map) { described_class.new(report_component, report_source, tracked_context) }

      before do
        occurrence_map.occurrence_id = 5
      end

      it 'exposes the grouping attributes' do
        expect(occurrence_map.to_h).to include(
          sbom_occurrence_id: 5,
          security_project_tracked_context_id: tracked_context.id
        )
      end
    end
  end

  describe '#security_project_tracked_context_id' do
    let_it_be(:tracked_context) { build_stubbed(:security_project_tracked_context) }

    it 'returns the id of the tracked context' do
      map = described_class.new(report_component, report_source, tracked_context)

      expect(map.security_project_tracked_context_id).to eq(tracked_context.id)
    end

    it 'returns nil when no tracked context is set' do
      expect(occurrence_map.security_project_tracked_context_id).to be_nil
    end
  end

  describe '#version_present?' do
    it 'returns true when a version is present' do
      expect(occurrence_map.version_present?).to be(true)
    end

    context 'when version is empty' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, version: '') }

      specify { expect(occurrence_map.version_present?).to be(false) }
    end

    context 'when version is absent' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, version: nil) }

      it { expect(occurrence_map.version_present?).to be(false) }
    end
  end

  describe '#input_file_path' do
    context 'when component was found by trivy' do
      let_it_be(:report_source) { build_stubbed(:ci_reports_sbom_source, :container_scanning, image_tag: '5.1-1234') }

      subject(:input_file_path) { occurrence_map.input_file_path }

      context 'with os package type' do
        let_it_be(:report_component_properties) do
          build_stubbed(:ci_reports_sbom_source, type: :trivy, data: { 'PkgType' => 'alpine' })
        end

        let_it_be(:report_component) do
          build_stubbed(:ci_reports_sbom_component, purl_type: 'apk', properties: report_component_properties)
        end

        it 'returns a container-image path' do
          expect(input_file_path).to eq('container-image:photon:5.1-1234')
        end
      end

      context 'with programming language package type' do
        let_it_be(:report_component_properties) do
          build_stubbed(:ci_reports_sbom_source, type: :trivy, data: {
            'PkgType' => 'node-pkg',
            'FilePath' => 'usr/local/lib/node_modules/retire/node_modules/escodegen/package.json'
          })
        end

        let_it_be(:report_component) do
          build_stubbed(:ci_reports_sbom_component, purl_type: 'npm', properties: report_component_properties)
        end

        it 'returns a container-image path' do
          expect(input_file_path).to eq('container-image:photon:5.1-1234')
        end
      end

      context 'when component was found by gemnasium' do
        context 'when gemnasium sbom was merged with trivy sbom' do
          let_it_be(:report_source) do
            build_stubbed(:ci_reports_sbom_source, data: {
              'category' => 'development',
              'source_file' => { 'path' => 'package.json' },
              'input_file' => { 'path' => 'package-lock.json' },
              'package_manager' => { 'name' => 'npm' },
              'language' => { 'name' => 'JavaScript' },
              'image' => {
                'name' => 'docker.io/library/alpine',
                'tag' => '3.12'
              },
              'operating_system' => {
                'name' => 'Alpine',
                'version' => '3.12'
              }
            })
          end

          let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component) }

          it 'returns a repository path' do
            expect(input_file_path).to eq('package-lock.json')
          end
        end
      end
    end
  end

  describe '#packager' do
    subject { occurrence_map.packager }

    context 'when component was found by gemnasium' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, purl_type: 'npm') }

      it { is_expected.to eq('npm') }
    end

    context 'when component was found by trivy' do
      context 'when component is an os package' do
        let_it_be(:report_component_properties) do
          build_stubbed(:ci_reports_sbom_source, type: :trivy, data: { 'PkgType' => 'alpine' })
        end

        let_it_be(:report_component) do
          build_stubbed(:ci_reports_sbom_component, purl_type: 'apk', properties: report_component_properties)
        end

        it do
          is_expected.to eq('apk')
        end
      end

      context 'when component is a language pack' do
        let_it_be(:report_component_properties) do
          build_stubbed(:ci_reports_sbom_source, type: :trivy, data: {
            'PkgType' => 'node-pkg',
            'FilePath' => 'usr/local/lib/node_modules/retire/node_modules/escodegen/package.json'
          })
        end

        let_it_be(:report_component) do
          build_stubbed(:ci_reports_sbom_component, purl_type: 'npm', properties: report_component_properties)
        end

        it { is_expected.to eq('npm') }
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:name).to(:report_component) }
    it { is_expected.to delegate_method(:version).to(:report_component) }
    it { is_expected.to delegate_method(:source_package_name).to(:report_component) }
  end

  context 'without vulnerability data' do
    it { expect(occurrence_map.vulnerability_ids).to eq [] }
  end

  describe '#occurrence_changed' do
    it 'defaults to false' do
      expect(occurrence_map.occurrence_changed).to be(false)
    end

    it 'is writable' do
      occurrence_map.occurrence_changed = true

      expect(occurrence_map.occurrence_changed).to be(true)
    end
  end
end
