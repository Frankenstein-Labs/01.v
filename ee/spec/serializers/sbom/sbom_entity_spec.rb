# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SbomEntity, feature_category: :dependency_management do
  let(:metadata) { build(:ci_reports_sbom_metadata) }
  let(:components) { build_list(:ci_reports_sbom_component, 5).map { |c| to_hashie_mash(c, licenses) } }
  let(:report) { build(:ci_reports_sbom_report, :with_metadata, metadata: metadata, components: components) }
  let(:reports) { [report] }
  let(:licenses) do
    [
      { name: "MIT", spdx_identifier: "MIT" },
      { name: "BSD-3-Clause", spdx_identifier: "BSD-3-Clause" }
    ]
  end

  subject { described_class.new(report).as_json }

  it 'has sbom attributes' do
    expect(subject).to include(:bomFormat, :specVersion, :serialNumber, :version, :metadata)
  end

  it 'has sbom components attributes' do
    expect(subject[:components].first.keys.sort).to include(:name, :purl, :type, :version)
  end

  context 'with a known license type' do
    let(:licenses) do
      [
        { name: "MIT", spdx_identifier: "MIT" },
        { name: "BSD-3-Clause", spdx_identifier: "BSD-3-Clause" }
      ]
    end

    it 'has sbom licenses attributes' do
      expect(subject[:components].first.keys.sort).to include(:licenses, :name, :purl, :type, :version)
      expect(subject[:components].first[:licenses]).to eq(
        [
          { license: { id: "MIT", url: "https://spdx.org/licenses/MIT.html" } },
          { license: { id: "BSD-3-Clause", url: "https://spdx.org/licenses/BSD-3-Clause.html" } }
        ]
      )
    end
  end

  context 'with an unknown license type' do
    let(:licenses) do
      [
        { name: "unknown", spdx_identifier: "unknown" },
        { name: "BSD-3-Clause", spdx_identifier: "BSD-3-Clause" }
      ]
    end

    it 'has sbom licenses attributes' do
      expect(subject[:components].first.keys.sort).to include(:licenses, :name, :purl, :type, :version)
      expect(subject[:components].first[:licenses]).to eq(
        [
          { license: { name: "unknown" } },
          { license: { id: "BSD-3-Clause", url: "https://spdx.org/licenses/BSD-3-Clause.html" } }
        ]
      )
    end
  end

  describe 'with incomplete or problematic license data' do
    license_test_cases = [
      {
        title: 'valid ID, custom name',
        license_data: [{ name: "Some License", spdx_identifier: "Apache-2.0" }],
        expected_licenses: [{ license: { id: "Apache-2.0", url: "https://spdx.org/licenses/Apache-2.0.html" } }]
      },

      {
        title: 'unknown ID, unknown name',
        license_data: [{ name: "unknown", spdx_identifier: "unknown" }],
        expected_licenses: [{ license: { name: "unknown" } }]
      },

      {
        title: 'nil ID, custom name',
        license_data: [{ name: "Some License", spdx_identifier: nil }],
        expected_licenses: [{ license: { name: "Some License" } }]
      },

      {
        title: 'empty ID, custom name',
        license_data: [{ name: "Some License", spdx_identifier: "" }],
        expected_licenses: [{ license: { name: "Some License" } }]
      },

      {
        title: 'unknown ID, custom name',
        license_data: [{ name: "Some License", spdx_identifier: "unknown" }],
        expected_licenses: [{ license: { name: "Some License" } }]
      },

      {
        title: 'valid ID, nil name',
        license_data: [{ name: nil, spdx_identifier: "Apache-2.0" }],
        expected_licenses: [{ license: { id: "Apache-2.0", url: "https://spdx.org/licenses/Apache-2.0.html" } }]
      },

      {
        title: 'valid ID, empty name',
        license_data: [{ name: "", spdx_identifier: "Apache-2.0" }],
        expected_licenses: [{ license: { id: "Apache-2.0", url: "https://spdx.org/licenses/Apache-2.0.html" } }]
      },

      {
        title: 'valid ID, unknown name',
        license_data: [{ name: "unknown", spdx_identifier: "Apache-2.0" }],
        expected_licenses: [{ license: { id: "Apache-2.0", url: "https://spdx.org/licenses/Apache-2.0.html" } }]
      }
    ]

    license_test_cases.each do |test_case|
      context "with #{test_case[:title]}" do
        let(:licenses) { test_case[:license_data] }

        it "formats license data correctly" do
          expect(subject[:components].first[:licenses]).to eq(test_case[:expected_licenses])
          validate_cyclonedx
        end
      end
    end
  end

  context 'with components missing version' do
    let(:components) do
      [
        to_hashie_mash(build(:ci_reports_sbom_component), licenses),
        to_hashie_mash(build(:ci_reports_sbom_component, version: nil), licenses)
      ]
    end

    it 'omits version field for components with nil version' do
      expect(subject[:components][0].keys).to include(:version)
      expect(subject[:components][1].keys).not_to include(:version)
      validate_cyclonedx
    end
  end

  context 'with components having empty or nil licenses' do
    let(:components) do
      [
        to_hashie_mash(build(:ci_reports_sbom_component), licenses),
        to_hashie_mash(build(:ci_reports_sbom_component), []),
        to_hashie_mash(build(:ci_reports_sbom_component), nil)
      ]
    end

    it 'omits licenses field for components with empty or nil licenses' do
      expect(subject[:components][0].keys).to include(:licenses)
      expect(subject[:components][1].keys).not_to include(:licenses)
      expect(subject[:components][2].keys).not_to include(:licenses)
      validate_cyclonedx
    end
  end

  def to_hashie_mash(component, licenses)
    Hashie::Mash.new(name: component.name, purl: "pkg:#{component.purl_type}/#{component.name}@#{component.version}",
      version: component.version, type: component.component_type, purl_type: component.purl_type,
      licenses: licenses
    )
  end

  def validate_cyclonedx
    report = ::Gitlab::Json.parse(subject.to_json)
    validator = Gitlab::Ci::Parsers::Sbom::Validators::CyclonedxSchemaValidator.new(report)
    expect(validator).to be_valid
  end
end
