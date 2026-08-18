# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::LicensesFetcher, feature_category: :dependency_management do
  let_it_be_with_reload(:project) { create(:project) }

  let_it_be(:unknown_licenses_spdx_identifier) do
    Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE[:spdx_identifier]
  end

  let_it_be(:unknown_licenses_name) { Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE[:name] }
  let_it_be(:unknown_licenses_url) { Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE[:url] }
  let_it_be(:unknown_licenses_count) { 1 }

  let(:unknown_license) do
    {
      'name' => "#{unknown_licenses_count} #{unknown_licenses_name}",
      'spdx_identifier' => unknown_licenses_spdx_identifier,
      'url' => unknown_licenses_url
    }.symbolize_keys
  end

  let_it_be(:unknown_ci_reports_sbom_license) do
    build(:ci_reports_sbom_license, name: unknown_licenses_name,
      spdx_identifier: unknown_licenses_spdx_identifier)
  end

  let_it_be(:component_without_license) { create(:ci_reports_sbom_component, licenses: nil) }
  let_it_be(:component_with_license) do
    create(:ci_reports_sbom_component,
      licenses: [build(:ci_reports_sbom_license, name: 'DOC License', spdx_identifier: 'DOC')])
  end

  let_it_be(:component_with_license_blank_spdx) do
    create(:ci_reports_sbom_component, licenses: [
      build(:ci_reports_sbom_license, spdx_identifier: nil),
      build(:ci_reports_sbom_license, spdx_identifier: "  ")
    ])
  end

  let_it_be(:occurrence_map_without_license) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_without_license)
  end

  let_it_be(:occurrence_map_with_license) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_with_license)
  end

  let_it_be(:occurrence_map_with_license_blank_spdx) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_with_license_blank_spdx)
  end

  let_it_be(:component_with_all_unknown_licenses) do
    create(:ci_reports_sbom_component,
      licenses: [unknown_ci_reports_sbom_license, unknown_ci_reports_sbom_license])
  end

  let_it_be(:occurrence_map_with_all_unknown_licenses) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion,
      report_component: component_with_all_unknown_licenses)
  end

  let_it_be(:component_with_mixed_licenses) do
    create(:ci_reports_sbom_component, licenses: [
      build(:ci_reports_sbom_license, name: 'Apache 2.0 License', spdx_identifier: 'Apache-2.0',
        url: 'https://spdx.org/licenses/Apache-2.0.html'),
      unknown_ci_reports_sbom_license
    ])
  end

  let_it_be(:occurrence_map_with_mixed_licenses) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_with_mixed_licenses)
  end

  let_it_be(:component_with_expression) do
    create(:ci_reports_sbom_component,
      licenses: [build(:ci_reports_sbom_license, :with_expression)])
  end

  let_it_be(:occurrence_map_with_expression) do
    create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_with_expression)
  end

  describe '#initialize' do
    let(:license_fetcher) { described_class.new(project, occurrence_maps) }

    shared_examples 'it ignores invalid or missing components' do
      it 'ignores invalid or missing components' do
        expect(license_fetcher.components).to be_empty
      end
    end

    context 'when the component does not have a purl' do
      let_it_be(:component_without_purl) { create(:ci_reports_sbom_component, purl: nil) }
      let_it_be(:occurrence_map_without_purl) do
        create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component_without_purl)
      end

      let_it_be(:occurrence_maps) { [occurrence_map_without_purl] }

      it_behaves_like 'it ignores invalid or missing components'
    end

    context 'when the component is missing' do
      let_it_be(:occurrence_map_without_component) do
        create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: nil)
      end

      let_it_be(:occurrence_maps) { [occurrence_map_without_component] }

      it_behaves_like 'it ignores invalid or missing components'
    end
  end

  describe '#fetch' do
    let_it_be(:occurrence_maps) do
      [occurrence_map_without_license, occurrence_map_with_license, occurrence_map_with_license_blank_spdx,
        occurrence_map_with_all_unknown_licenses, occurrence_map_with_mixed_licenses]
    end

    let(:license_fetcher) { described_class.new(project, occurrence_maps) }

    subject(:licenses) { license_fetcher.fetch(report_component) }

    context 'with license_scanning_for_cyclonedx security setting' do
      let_it_be_with_reload(:project) { create(:project) }
      let(:license_fetcher) { described_class.new(project, occurrence_maps) }
      let(:report_component) { component_with_license }

      it 'returns licenses normally' do
        expect(licenses).not_to be_empty
      end

      context 'when license scanning is disabled' do
        before do
          project.security_setting.update!(license_scanning_for_cyclonedx_enabled: false)
        end

        it 'returns the unknown license' do
          expect(licenses).to match_array([unknown_license])
        end

        context 'when the component has blank spdx identifiers' do
          let(:report_component) { component_with_license_blank_spdx }

          it 'returns the unknown license instead of empty' do
            expect(licenses).to match_array([unknown_license])
          end
        end
      end

      context 'when security_setting is nil' do
        before do
          allow(project).to receive(:security_setting).and_return(nil)
        end

        it 'returns licenses normally' do
          expect(licenses).not_to be_empty
        end
      end
    end

    shared_examples_for 'when SBOM provides licenses for the component' do
      let_it_be(:report_licenses) do
        [{ 'name' => 'DOC License', 'spdx_identifier' => 'DOC', 'url' => 'https://spdx.org/licenses/DOC.html' }]
      end

      context 'when SBOM provides licenses for the component' do
        let(:report_component) { component_with_license }

        it 'returns the license according to the information provided in the report' do
          expect(licenses).to match_array(report_licenses)
        end
      end
    end

    context 'when the components license are not persisted in the database' do
      let(:report_component) { component_without_license }

      context 'when SBOM does not provides licenses for the component' do
        it 'returns the unknown_license' do
          expect(licenses).to match_array([unknown_license])
        end
      end

      it_behaves_like 'when SBOM provides licenses for the component'
    end

    context 'when the components license are persisted in the database' do
      let_it_be(:database_licenses) do
        [
          { name: 'Apache License 2.0', spdx_identifier: 'Apache-2.0',
            url: 'https://spdx.org/licenses/Apache-2.0.html' },
          { name: 'MIT License', spdx_identifier: 'MIT', url: 'https://spdx.org/licenses/MIT.html' }
        ]
      end

      let_it_be(:database_license_names) { database_licenses.pluck(:spdx_identifier) }

      before do
        occurrence_maps.map(&:report_component).each do |component|
          next if component.purl.blank?

          create(
            :pm_package,
            name: component.name,
            purl_type: component.purl&.type,
            lowest_version: component.version,
            highest_version: component.version,
            default_license_names: database_license_names
          )
        end
      end

      it_behaves_like 'when SBOM provides licenses for the component'

      context 'when the SBOM does not provide licenses for the component' do
        let(:report_component) { component_without_license }

        it 'sets the license using the license database' do
          expect(licenses).to match_array(database_licenses)
        end
      end

      context 'when the SBOM provides licenses with blank or missing spdx_identifier field' do
        let_it_be(:report_component) { component_with_license_blank_spdx }

        it 'does not set a license' do
          expect(licenses).to be_empty
        end
      end

      context 'when SBOM provides all unknown licenses for a component' do
        let(:unknown_licenses_count) { 2 }
        let(:report_licenses_unknown) { [unknown_license] }

        let_it_be(:report_component) { component_with_all_unknown_licenses }

        it 'returns an unknown license with name 2 unknown licenses' do
          expect(licenses).to match_array(report_licenses_unknown)
        end
      end

      context 'when SBOM provides mixed known and unknown licenses for a component' do
        let(:mixed_licenses) do
          [
            {
              'name' => 'Apache 2.0 License',
              'spdx_identifier' => 'Apache-2.0',
              'url' => 'https://spdx.org/licenses/Apache-2.0.html'
            },
            unknown_license
          ]
        end

        let_it_be(:report_component) { component_with_mixed_licenses }

        it 'returns mixed licenses' do
          expect(licenses).to match_array(mixed_licenses)
        end
      end
    end

    context 'when the SBOM provides a license expression' do
      let_it_be(:occurrence_maps) { [occurrence_map_with_expression] }

      let(:license_expression) { component_with_expression.licenses.first.expression }
      let(:license_fetcher) { described_class.new(project, occurrence_maps) }
      let(:report_component) { component_with_expression }

      it 'persists the expression and falls back to it for the non-nullable name' do
        expect(licenses).to match_array([
          {
            'name' => license_expression,
            'spdx_identifier' => nil,
            'url' => nil,
            'expression' => license_expression
          }
        ])
      end
    end
  end
end
