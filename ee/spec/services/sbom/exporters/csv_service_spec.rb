# frozen_string_literal: true

require 'spec_helper'
require './ee/spec/services/sbom/exporters/file_helper'

RSpec.describe Sbom::Exporters::CsvService, feature_category: :dependency_management do
  include FileHelper

  # `freeze: false` is required here: this `let_it_be` subject is mutated
  # in-memory across examples in a way that survives both
  # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
  # association/collection or a non-persisted attribute). Keeping it unfrozen
  # is the only correct cure (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:export) { build_stubbed(:dependency_list_export) }
  # `freeze: false` is required here: this `let_it_be` subject is mutated
  # in-memory across examples in a way that survives both
  # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
  # association/collection or a non-persisted attribute). Keeping it unfrozen
  # is the only correct cure (see gitlab-org/gitlab#602925).
  let_it_be(:sbom_occurrences, freeze: false) { Sbom::Occurrence.all }

  let(:service_class) { described_class.new(export, sbom_occurrences) }

  describe 'OccurrenceWithOverriddenLicenses' do
    subject(:wrapper) { described_class::OccurrenceWithOverriddenLicenses.new(occurrence, overridden) }

    let(:occurrence) { instance_double(Sbom::Occurrence, name: 'rails', version: '7.0') }
    let(:overridden) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0' }] }

    it 'delegates non-license methods to the wrapped occurrence' do
      expect(wrapper.name).to eq('rails')
      expect(wrapper.version).to eq('7.0')
    end

    it 'overrides the licenses method with the provided value' do
      expect(wrapper.licenses).to eq(overridden)
    end
  end

  describe '.header' do
    subject { described_class.header }

    it 'returns correct headers' do
      is_expected.to eq(
        "Name,Version,Packager,Location,License Identifiers,Project,Vulnerabilities Detected,Vulnerability IDs\n")
    end
  end

  describe '.combine_parts' do
    let(:header) do
      "Name,Version,Packager,Location,License Identifiers,Project,Vulnerabilities Detected,Vulnerability IDs"
    end

    let(:part_1) do
      stub_file("#{header}\naccepts,1.3.5,npm,/enterprise/node/-/blob/" \
        "9e800c181208cc6539b4d257096921af79c86653/package-lock.json,\"\",enterprise/node,0,\"\"\n")
    end

    let(:part_2) do
      stub_file("#{header}\nacorn,3.3.0,npm,/enterprise/node/-/blob/" \
        "9e800c181208cc6539b4d257096921af79c86653/package-lock.json,\"\",enterprise/node,0,\"\"\n")
    end

    subject(:combined_parts) { described_class.combine_parts([part_1, part_2]) }

    after do
      part_1.close!
      part_2.close!
    end

    it 'combines the parts with header' do
      expect(combined_parts).to eq(
        <<~CSV
        #{header}
        accepts,1.3.5,npm,/enterprise/node/-/blob/9e800c181208cc6539b4d257096921af79c86653/package-lock.json,"",enterprise/node,0,""
        acorn,3.3.0,npm,/enterprise/node/-/blob/9e800c181208cc6539b4d257096921af79c86653/package-lock.json,"",enterprise/node,0,""
        CSV
      )
    end
  end

  context 'when block is not given' do
    it 'renders csv to string' do
      expect(service_class.generate).to be_a String
    end
  end

  context 'when block is given' do
    it 'returns handle to Tempfile' do
      expect(service_class.generate { |file| file }).to be_a Tempfile
    end
  end

  describe '#generate' do
    subject(:csv) { CSV.parse(service_class.generate, headers: true) }

    let(:header) do
      [
        'Name',
        'Version',
        'Packager',
        'Location',
        'License Identifiers',
        'Project',
        'Vulnerabilities Detected',
        'Vulnerability IDs'
      ]
    end

    context 'when the exportable does not have dependencies' do
      it { is_expected.to match_array([header]) }
    end

    context 'when the exportable has dependencies' do
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:bundler, freeze: false) { create(:sbom_component, :bundler) }
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:bundler_v1, freeze: false) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:occurrence, freeze: false) do
        create(:sbom_occurrence, :mit, :with_vulnerabilities,
          project: project,
          component: bundler,
          component_version: bundler_v1
        )
      end

      it 'returns correct content' do
        expect(csv[0]['Name']).to eq(occurrence.name)
        expect(csv[0]['Version']).to eq(occurrence.version)
        expect(csv[0]['Packager']).to eq(occurrence.package_manager)
        expect(csv[0]['Location']).to eq(occurrence.location[:blob_path])
        expect(csv[0]['License Identifiers']).to eq('MIT')
        expect(csv[0]['Project']).to eq(project.full_path)
        expect(csv[0]['Vulnerabilities Detected']).to eq('2')

        expected_vulnerabilities = occurrence.vulnerabilities.pluck(:id).join('; ')
        expect(csv[0]['Vulnerability IDs']).to eq(expected_vulnerabilities)
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          service_class.generate
        end

        create_list(:sbom_occurrence, 3, :with_vulnerabilities,
          project: project, source: create(:sbom_source))

        expect do
          service_class.generate
        end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency.or_fewer
      end
    end

    context 'when license overrides are configured' do
      let_it_be(:bundler, freeze: false) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1, freeze: false) { create(:sbom_component_version, component: bundler, version: '1.0.0') }
      let_it_be(:occurrence, freeze: false) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:overridden_id) { 'Apache-2.0' }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:new).and_return(applicator)
        allow(applicator).to receive(:apply).and_return([{ 'spdx_identifier' => overridden_id }])
      end

      it 'uses overridden license identifiers in the CSV output' do
        expect(csv[0]['License Identifiers']).to eq(overridden_id)
      end
    end

    context 'when the group has an orphaned dependency' do
      # Project shouldn't be nil, but occasionally an SbomOccurrence could be orphaned when
      # a project is deleted.
      # Tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/541931
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:kept_occurrence, freeze: false) { create(:sbom_occurrence, :mit, project: project) }
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:orphaned_occurrence, freeze: false) do
        # To simulate this, we start with a fully valid project...
        occurrence = create(:sbom_occurrence, :apache_2, project: project)
        # ...then we orphan the record by setting the project_id to a not-found value.
        # project_id_seq starts from 1, so 0 is always invalid.
        occurrence.project_id = 0
        occurrence.save!(validate: false)
        # We could do this by creating a project, associating it to the occurrence then
        # deleting the project, but that was then cascading the delete to the occurrence
        # (as it should!) which was making this test setup hard. This achieves the same
        # end setup through a slightly different means.
        occurrence
      end

      it 'excludes the orphaned occurrence' do
        expect(csv.length).to be 1
        expect(csv[0]['Name']).to eq(kept_occurrence.name)
        expect(csv[0]['Version']).to eq(kept_occurrence.version)
        expect(csv[0]['Packager']).to eq(kept_occurrence.package_manager)
        expect(csv[0]['Location']).to eq(kept_occurrence.location[:blob_path])
        expect(csv[0]['License Identifiers']).to eq('MIT')
        expect(csv[0]['Project']).to eq(project.full_path)
        expect(csv[0]['Vulnerabilities Detected']).to eq('0')
      end
    end
  end
end
