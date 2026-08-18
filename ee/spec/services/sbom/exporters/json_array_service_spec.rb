# frozen_string_literal: true

require 'spec_helper'
require './ee/spec/services/sbom/exporters/file_helper'

RSpec.describe Sbom::Exporters::JsonArrayService, feature_category: :dependency_management do
  include FileHelper

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }

  describe '.combine_parts' do
    let(:part_1) do
      stub_file('{"a": "b"}')
    end

    let(:part_2) do
      stub_file('{"b": "c"}')
    end

    subject(:combined_parts) { described_class.combine_parts([part_1, part_2]) }

    after do
      part_1.close!
      part_2.close!
    end

    it 'combines the parts into a flat array' do
      expect(combined_parts).to eq(
        <<~JSON
        [
          {"a": "b"},
          {"b": "c"}
        ]
        JSON
      )
    end
  end

  describe '#generate' do
    let(:sbom_occurrences) { Sbom::Occurrence.for_namespace_and_descendants(group).order_by_id }
    let(:service_class) { described_class.new(nil, sbom_occurrences) }

    subject(:dependencies) { Gitlab::Json.parse(service_class.generate) }

    before do
      stub_licensed_features(dependency_scanning: true)
    end

    context 'when the group does not have dependencies' do
      it { is_expected.to be_empty }
    end

    context 'when the group has dependencies' do
      let_it_be(:bundler) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }

      let_it_be(:occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      let_it_be(:other_occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      it 'includes each occurrence excluding archived projects' do
        expect(dependencies).to eq([
          {
            "name" => occurrence_1.component_name,
            "version" => occurrence_1.version,
            "packager" => occurrence_1.package_manager,
            "licenses" => occurrence_1.licenses,
            "location" => occurrence_1.location.as_json
          },
          {
            "name" => occurrence_2.component_name,
            "version" => occurrence_2.version,
            "packager" => occurrence_2.package_manager,
            "licenses" => occurrence_2.licenses,
            "location" => occurrence_2.location.as_json
          },
          {
            "name" => occurrence_3.component_name,
            "version" => occurrence_3.version,
            "packager" => occurrence_3.package_manager,
            "licenses" => occurrence_3.licenses,
            "location" => occurrence_3.location.as_json
          },
          {
            "name" => occurrence_of_bundler_v1.component_name,
            "version" => occurrence_of_bundler_v1.version,
            "packager" => occurrence_of_bundler_v1.package_manager,
            "licenses" => occurrence_of_bundler_v1.licenses,
            "location" => occurrence_of_bundler_v1.location.as_json
          },
          {
            "name" => other_occurrence_of_bundler_v1.component_name,
            "version" => other_occurrence_of_bundler_v1.version,
            "packager" => other_occurrence_of_bundler_v1.package_manager,
            "licenses" => other_occurrence_of_bundler_v1.licenses,
            "location" => other_occurrence_of_bundler_v1.location.as_json
          }
        ])
      end
    end

    context 'when license overrides are configured' do
      let_it_be(:occurrence) { create(:sbom_occurrence, :mit, project: project) }
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:overridden_licenses) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0' }] }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:new).and_return(applicator)
        allow(applicator).to receive(:apply).and_return(overridden_licenses)
      end

      it 'applies license overrides in generated JSON' do
        expect(dependencies.first['licenses']).to eq(overridden_licenses)
      end
    end

    context 'when the group has an orphaned dependency' do
      # Project shouldn't be nil, but occasionally an SbomOccurrence could be orphaned when
      # a project is deleted.
      # Tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/541931
      let_it_be(:kept_occurrence) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:orphaned_occurrence) do
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
        expect(dependencies).to eq([
          {
            "name" => kept_occurrence.component_name,
            "version" => kept_occurrence.version,
            "packager" => kept_occurrence.package_manager,
            "licenses" => kept_occurrence.licenses,
            "location" => kept_occurrence.location.as_json
          }
        ])
      end
    end
  end

  describe '#generate_part' do
    let_it_be(:occurrences_by_name) do
      [
        create(:sbom_occurrence, :mit, project: project),
        create(:sbom_occurrence, :apache_2, project: project)
      ].index_by(&:component_name)
    end

    subject(:data) { described_class.new(nil, project.sbom_occurrences).generate_part }

    def json_data(object)
      occurrence = occurrences_by_name[object['name']]

      {
        'name' => occurrence.component_name,
        'packager' => occurrence.package_manager,
        'version' => occurrence.version,
        'licenses' => occurrence.licenses,
        'location' => occurrence.location.stringify_keys
      }
    end

    it 'writes data with one JSON object per line' do
      # JSON does not have ordering guarantees so we need to parse the
      # data to ensure a consistent result.
      stream = StringIO.new(data)
      stream.each_line do |line|
        object = Gitlab::Json.parse(line)
        expect(object).to eq(json_data(object))
      end
    end

    it 'does not have N+1 queries' do
      control = ActiveRecord::QueryRecorder.new { described_class.new(nil, project.sbom_occurrences).generate_part }

      create(:sbom_occurrence, :mit, project: project)

      expect { described_class.new(nil, project.sbom_occurrences).generate_part }.not_to exceed_query_limit(control)
    end
  end
end
