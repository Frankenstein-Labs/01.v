# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Occurrence, type: :model, feature_category: :dependency_management do
  let_it_be(:occurrence) { build(:sbom_occurrence) }

  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to belong_to(:component_version) }
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:source) }
    it { is_expected.to belong_to(:source_package) }
    it { is_expected.to have_many(:occurrences_vulnerabilities) }
    it { is_expected.to have_many(:vulnerabilities) }

    describe '#pipeline' do
      it_behaves_like 'a partition-pruned pipeline association' do
        # .reload clears the :pipeline target cached by the attribute writer.
        let(:related_resource) { create(:sbom_occurrence, pipeline: pipeline).reload }
      end
    end
  end

  describe '#policy_dismissals' do
    it 'returns [] by default' do
      expect(occurrence.policy_dismissals).to eq([])
    end

    it 'returns assigned value' do
      dismissal = build_stubbed(:policy_dismissal)
      occurrence.policy_dismissals = [dismissal]

      expect(occurrence.policy_dismissals).to eq([dismissal])
    end
  end

  describe 'loose foreign key on sbom_occurrences.pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:sbom_occurrence, pipeline: parent) }
    end
  end

  describe 'validations' do
    subject { build(:sbom_occurrence) }

    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }
    it { is_expected.to validate_length_of(:commit_sha).is_at_most(64) }
    it { is_expected.to validate_length_of(:package_manager).is_at_most(255) }
    it { is_expected.to validate_length_of(:component_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:input_file_path).is_at_most(1024) }

    describe '#licenses' do
      subject { build(:sbom_occurrence, licenses: licenses) }

      let(:apache) do
        {
          spdx_identifier: 'Apache-2.0',
          name: 'Apache License 2.0',
          url: 'http://spdx.org/licenses/Apache-2.0.html'
        }
      end

      let(:mit) do
        {
          spdx_identifier: 'MIT',
          name: 'MIT License',
          url: 'http://spdx.org/licenses/MIT.html'
        }
      end

      context 'when licenses is empty' do
        let(:licenses) { [] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has a single valid license' do
        let(:licenses) { [mit] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has multiple valid licenses' do
        let(:licenses) { [apache, mit] }

        it { is_expected.to be_valid }
      end

      context 'when spdx_identifier is missing' do
        let(:licenses) { [mit.except(:spdx_identifier)] }

        context 'when the name is not missing' do
          it { is_expected.to be_valid }
        end

        context 'when the name is missing' do
          let(:licenses) { [mit.except(:spdx_identifier, :name)] }

          it { is_expected.to be_invalid }
        end
      end

      context 'when spdx_identifier is blank' do
        let(:licenses) { [mit.merge(spdx_identifier: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when spdx_identifier is too long' do
        # max length derived from `pm_licenses`.`spdx_identifier` column
        let(:licenses) { [mit.merge(spdx_identifier: 'X' * 256)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license name is missing' do
        let(:licenses) { [mit.except(:name)] }

        context 'when the spdx_identifier is not missing' do
          it { is_expected.to be_valid }
        end

        context 'when the spdx_identifier is missing' do
          let(:licenses) { [mit.except(:spdx_identifier, :name)] }

          it { is_expected.to be_invalid }
        end
      end

      context 'when a license name is blank' do
        let(:licenses) { [mit.merge(name: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license url is missing' do
        let(:licenses) { [mit.except(:url)] }

        it { is_expected.to be_valid }
      end

      context 'when a license url is blank' do
        let(:licenses) { [mit.merge(url: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license contains unknown properties' do
        let(:licenses) { [mit.merge(unknown: 'value')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license carries an spdx expression' do
        let(:licenses) { [mit.merge(expression: 'MIT OR Apache-2.0')] }

        it { is_expected.to be_valid }
      end

      context 'when the expression is too long' do
        let(:licenses) { [mit.merge(expression: 'X' * 1025)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license is only an expression' do
        let(:licenses) { [{ name: 'MIT OR Apache-2.0', expression: 'MIT OR Apache-2.0' }] }

        it { is_expected.to be_valid }
      end

      context 'when a license has an expression but no spdx_identifier or name' do
        let(:licenses) { [{ expression: 'MIT OR Apache-2.0' }] }

        it { is_expected.to be_invalid }
      end
    end
  end

  describe '.filter_by_components scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'returns occurrences matching the given components' do
      expect(described_class.filter_by_components([matching_occurrence.component])).to eq([matching_occurrence])
    end

    it 'returns occurrences matching the given component ids' do
      expect(described_class.filter_by_components([matching_occurrence.component.id])).to eq([matching_occurrence])
    end
  end

  describe '.with_component_source_version_and_project scope' do
    let_it_be(:occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'pre-loads relations to avoid executing additional queries' do
      record = described_class.with_component_source_version_and_project.first

      queries = ActiveRecord::QueryRecorder.new do
        record.component
        record.component_version
        record.source
        record.project
      end

      expect(queries.count).to be_zero
    end
  end

  describe '.with_project_setting' do
    let!(:occurrence) { create(:sbom_occurrence) }

    it 'pre-loads relations to avoid executing additional queries' do
      record = described_class.with_project_setting.first

      queries = ActiveRecord::QueryRecorder.new do
        record.project
        record.project.project_setting
      end

      expect(queries.count).to be_zero
    end
  end

  describe '.with_pipeline_project_and_namespace' do
    let_it_be(:occurrence_one) { create(:sbom_occurrence, component: create(:sbom_component)) }
    let_it_be(:occurrence_two) { create(:sbom_occurrence, component: create(:sbom_component)) }
    let_it_be(:pipeline_one) { occurrence_one.pipeline }
    let_it_be(:pipeline_two) { occurrence_two.pipeline }

    let(:relation) { described_class.with_pipeline_project_and_namespace }

    it 'bulk-preloads the pipeline association without a per-record p_ci_pipelines query' do
      occurrences = relation.load.to_a

      expect(occurrences.map { |o| o.association(:pipeline).loaded? }).to all(be(true))

      expect do
        occurrences.each { |o| o.pipeline&.project&.namespace }
      end.not_to make_queries_matching(/SELECT.*p_ci_pipelines/)
    end

    it 'preloads the nested pipeline project and namespace' do
      record = relation.first

      queries = ActiveRecord::QueryRecorder.new do
        record.pipeline.project.namespace
      end

      expect(queries.count).to be_zero
    end

    context 'with a warm partition cache covering the pipeline ids' do
      before do
        min_id, max_id = [pipeline_one.id, pipeline_two.id].minmax
        create(:ci_partition, id: pipeline_one.partition_id, pipelines_id_range: (min_id..max_id))
        Gitlab::Ci::Pipeline::PartitionCache.invalidate
      end

      after do
        Gitlab::Ci::Pipeline::PartitionCache.invalidate
      end

      it 'prunes the pipeline lookup by partition_id' do
        recorder = ActiveRecord::QueryRecorder.new { relation.load }

        expect(recorder.log).to include(a_string_matching(/partition_id/))
      end
    end

    context 'when the partition_aware_pipeline_preload feature flag is disabled' do
      before do
        stub_feature_flags(partition_aware_pipeline_preload: false)
      end

      it 'falls back to a vanilla bulk preload' do
        expect(Gitlab::Ci::Pipeline::BulkByIdLookup).not_to receive(:new)

        occurrences = relation.load.to_a

        expect(occurrences.map { |o| o.association(:pipeline).loaded? }).to all(be(true))
      end
    end
  end

  describe '.filter_by_non_nil_component_version scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component_version: nil) }

    it 'returns occurrences with a non-nil component_version' do
      expect(described_class.filter_by_non_nil_component_version).to eq([matching_occurrence])
    end
  end

  describe '.order_by_id' do
    let_it_be(:first) { create(:sbom_occurrence) }
    let_it_be(:second) { create(:sbom_occurrence) }

    it 'returns records sorted by id' do
      expect(described_class.order_by_id).to eq([first, second])
    end
  end

  describe '.order_by_component_name' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_1')) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_2')) }

    it 'returns records sorted by component name asc' do
      expect(described_class.order_by_component_name('asc').map(&:name)).to eq(%w[component_1 component_2])
    end

    it 'returns records sorted by component name desc' do
      expect(described_class.order_by_component_name('desc').map(&:name)).to eq(%w[component_2 component_1])
    end
  end

  describe '.order_by_component_name_collated' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence, component_name: 'component_1') }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, component_name: 'component_2') }

    subject { described_class.order_by_component_name_collated(verse) }

    where(:verse) { %i[asc desc] }

    with_them do
      it { is_expected.to be_sorted(:component_name, verse) }
    end

    describe 'default' do
      subject { described_class.order_by_component_name_collated }

      it { is_expected.to be_sorted(:component_name, :asc) }
    end
  end

  describe '.order_by_package_name' do
    let_it_be(:occurrence_nuget_a) { create(:sbom_occurrence, component_name: 'component-a', packager_name: 'nuget') }
    let_it_be(:occurrence_nuget_b) { create(:sbom_occurrence, component_name: 'component-b', packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    subject(:relation) { described_class.order_by_package_name(order) }

    context 'when the sort order is ascending' do
      let(:order) { 'asc' }

      it 'returns records sorted by package name asc, component name asc' do
        expect(relation.to_a).to eq([occurrence_npm, occurrence_nuget_a, occurrence_nuget_b, occurrence_null])
      end
    end

    context 'when the sort order is descending' do
      let(:order) { 'desc' }

      it 'returns records sorted by package name desc, component name asc' do
        expect(relation.to_a).to eq([occurrence_null, occurrence_nuget_a, occurrence_nuget_b, occurrence_npm])
      end
    end
  end

  describe '.order_by_spdx_identifier' do
    let_it_be(:mit_occurrence) { create(:sbom_occurrence, :mit) }
    let_it_be(:apache_occurrence) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:apache_and_mpl_occurrence) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:apache_and_mit_occurrence) { create(:sbom_occurrence, :apache_2, :mit) }
    let_it_be(:mit_and_mpl_occurrence) { create(:sbom_occurrence, :mit, :mpl_2) }

    subject(:relation) { described_class.order_by_spdx_identifier(order) }

    context 'when sorting in ascending order' do
      let(:order) { 'asc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          apache_and_mit_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          mit_occurrence.licenses
        ])
      end
    end

    context 'when sorting in descending order' do
      let(:order) { 'desc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          mit_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_and_mit_occurrence.licenses
        ])
      end
    end

    context 'when a license does not have the spdx identifier' do
      let_it_be(:occurrence_license_without_spdx_id) { create(:sbom_occurrence, :license_without_spdx_id) }

      context 'when sorting in ascending order' do
        let(:order) { 'asc' }

        it 'returns the sorted records' do
          expect(relation.map(&:licenses)).to eq([
            apache_and_mit_occurrence.licenses,
            apache_and_mpl_occurrence.licenses,
            apache_occurrence.licenses,
            occurrence_license_without_spdx_id.licenses,
            mit_and_mpl_occurrence.licenses,
            mit_occurrence.licenses
          ])
        end
      end

      context 'when sorting in descending order' do
        let(:order) { 'desc' }

        it 'returns the sorted records' do
          expect(relation.map(&:licenses)).to eq([
            mit_occurrence.licenses,
            mit_and_mpl_occurrence.licenses,
            occurrence_license_without_spdx_id.licenses,
            apache_occurrence.licenses,
            apache_and_mpl_occurrence.licenses,
            apache_and_mit_occurrence.licenses
          ])
        end
      end
    end
  end

  describe '.order_by_severity' do
    let_it_be(:occurrence_critical) { create(:sbom_occurrence, highest_severity: :critical) }
    let_it_be(:occurrence_low) { create(:sbom_occurrence, highest_severity: :low) }

    it 'returns records sorted by highest_severity asc' do
      expect(described_class.order_by_severity('asc').map(&:highest_severity)).to eq(%w[low critical])
    end

    it 'returns records sorted by highest_severity desc' do
      expect(described_class.order_by_severity('desc').map(&:highest_severity)).to eq(%w[critical low])
    end
  end

  describe '.filter_by_component_names' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component name' do
      expect(described_class.filter_by_component_names([occurrence_1.name])).to eq([occurrence_1])
    end

    it 'returns records filtered by component name when using collation' do
      expect(described_class.by_component_name_collated([occurrence_1.name])).to eq([occurrence_1])
    end
  end

  describe '.filter_by_component_ids' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component IDs' do
      expect(described_class.filter_by_component_ids([occurrence_1.component_id])).to eq([occurrence_1])
    end
  end

  describe '.filter_by_component_version_ids' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component version IDs' do
      expect(described_class.filter_by_component_version_ids([occurrence_1.component_version_id])).to eq([occurrence_1])
    end
  end

  describe '.filter_by_non_component_version_ids' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component version IDs' do
      expect(described_class.filter_by_non_component_version_ids(
        [occurrence_1.component_version_id])).to eq([occurrence_2])
    end
  end

  describe '.filter_by_component_versions' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component versions' do
      expect(described_class.filter_by_component_versions(
        [occurrence_1.component_version.version])).to eq([occurrence_1])
    end
  end

  describe '.filter_by_non_component_versions' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component versions' do
      expect(described_class.filter_by_non_component_versions(
        [occurrence_1.component_version.version])).to eq([occurrence_2])
    end
  end

  describe '.filter_by_source_types' do
    let_it_be(:container_scanning_occurrence) { create(:sbom_occurrence, :os_occurrence) }
    let_it_be(:dependency_scanning_occurrence) { create(:sbom_occurrence) }

    it 'returns records filtered by source name' do
      expect(described_class.filter_by_source_types([:container_scanning])).to eq([container_scanning_occurrence])
    end
  end

  describe '.filter_by_source_id' do
    let_it_be(:sbom_source_1) { create(:sbom_source) }
    let_it_be(:sbom_source_2) { create(:sbom_source) }
    let_it_be(:occurrence_1) { create(:sbom_occurrence, source: sbom_source_1) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, source: sbom_source_2) }

    it 'returns records filtered by source_id' do
      expect(described_class.filter_by_source_id(sbom_source_1.id)).to eq([occurrence_1])
    end

    it 'returns an empty array if no records match the source_id' do
      expect(described_class.filter_by_source_id(non_existing_record_id)).to eq([])
    end
  end

  describe '.ref_orphaned' do
    let_it_be(:referenced_occurrence) { create(:sbom_occurrence) }
    let_it_be(:orphaned_occurrence) { create(:sbom_occurrence) }
    let_it_be(:ref) { create(:sbom_occurrence_ref, occurrence: referenced_occurrence) }

    it 'returns only occurrences that have no occurrence refs' do
      expect(described_class.ref_orphaned).to contain_exactly(orphaned_occurrence)
    end

    it 'excludes occurrences referenced in any tracked context' do
      create(:sbom_occurrence_ref, occurrence: orphaned_occurrence)

      expect(described_class.ref_orphaned).to be_empty
    end
  end

  describe '.by_licenses' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:occurrence_1) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :mit) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:occurrence_5) { create(:sbom_occurrence, :unknown) }

    where(:input, :expected) do
      %w[MIT MPL-2.0]     | [ref(:occurrence_2), ref(:occurrence_3), ref(:occurrence_4)]
      %w[MPL-2.0 unknown] | [ref(:occurrence_3), ref(:occurrence_4), ref(:occurrence_5)]
      %w[unknown]         | [ref(:occurrence_5)]
      []                  | []
    end

    with_them do
      it "returns the expected occurrences" do
        expect(described_class.by_licenses(input)).to match_array(expected)
      end
    end

    context 'when an occurrence only has an spdx expression' do
      let_it_be(:occurrence_expression) { create(:sbom_occurrence, :license_expression) }

      it 'is not matched when filtering by spdx identifier' do
        expect(described_class.by_licenses(%w[Apache-2.0 MIT])).not_to include(occurrence_expression)
      end
    end
  end

  describe '.by_primary_license' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:occurrence_1) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :mit) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:occurrence_5) { create(:sbom_occurrence, :unknown) }

    where(:input, :expected) do
      %w[MIT MPL-2.0]     | [ref(:occurrence_2), ref(:occurrence_3)]
      %w[MPL-2.0 unknown] | [ref(:occurrence_3), ref(:occurrence_5)]
      %w[unknown]         | [ref(:occurrence_5)]
      []                  | []
    end

    with_them do
      it "returns the expected occurrences" do
        expect(described_class.by_primary_license(input)).to match_array(expected)
      end
    end
  end

  describe '.unarchived' do
    let_it_be(:unarchived_occurrence) { create(:sbom_occurrence) }

    before_all do
      create(:sbom_occurrence, project: create(:project, :archived))
    end

    it 'returns only unarchived occurrences' do
      expect(described_class.unarchived).to eq([unarchived_occurrence])
    end
  end

  describe '.by_project_ids' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by project_id' do
      expect(described_class.by_project_ids(occurrence_1.project)).to eq([occurrence_1])
    end
  end

  describe '.by_uuids' do
    let_it_be(:occurrences) { create_list(:sbom_occurrence, 2) }

    specify { expect(described_class.by_uuids(occurrences.first.uuid)).to eq([occurrences.first]) }
  end

  describe '.filter_by_package_managers' do
    let_it_be(:occurrence_nuget) { create(:sbom_occurrence, packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    it 'returns records filtered by package name' do
      expect(described_class.filter_by_package_managers(%w[npm])).to eq([occurrence_npm])
    end

    context 'with empty array' do
      it 'returns no records' do
        expect(described_class.filter_by_package_managers([])).to eq([])
      end
    end
  end

  describe '.for_namespace_and_descendants' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, namespace: group) }
    let_it_be(:project2) { create(:project, namespace: group) }
    let_it_be(:occurrence_npm1) { create(:sbom_occurrence, project: project1) }
    let_it_be(:occurrence_npm2) { create(:sbom_occurrence, project: project2) }

    it 'returns records' do
      result = described_class.for_namespace_and_descendants(group)
      expect(result).to match_array([occurrence_npm1, occurrence_npm2])
    end
  end

  describe '.by_component_name_prefix' do
    let_it_be(:matches) do
      [
        create(:sbom_occurrence, component_name: 'activesupport'),
        create(:sbom_occurrence, component_name: 'activerecord')
      ]
    end

    before_all do
      create(:sbom_occurrence, component_name: 'somethingactive')
      create(:sbom_occurrence, component_name: 'ActiveSupport')
    end

    subject { described_class.by_component_name_prefix('active') }

    it { is_expected.to match_array(matches) }
  end

  describe '.by_component_name_substring' do
    let_it_be(:matches) do
      [
        create(:sbom_occurrence, component_name: 'activesupport'),
        create(:sbom_occurrence, component_name: 'activerecord'),
        create(:sbom_occurrence, component_name: 'somethingactive'),
        create(:sbom_occurrence, component_name: 'ActiveSupport')
      ]
    end

    before_all do
      create(:sbom_occurrence, component_name: 'a')
    end

    subject { described_class.by_component_name_substring('active') }

    it { is_expected.to match_array(matches) }
  end

  describe '.filter_by_search_with_component_and_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, project: project) }
    let_it_be(:source_npm) { occurrence_npm.source }
    let_it_be(:component_version) { occurrence_npm.component_version }
    let_it_be(:source_bundler) { create(:sbom_source, packager_name: 'bundler', input_file_path: 'Gemfile.lock') }
    let_it_be(:occurrence_bundler) do
      create(:sbom_occurrence, source: source_bundler, component_version: component_version, project: project)
    end

    context 'with different search keywords' do
      using RSpec::Parameterized::TableSyntax

      where(:keyword, :occurrences) do
        'file'  | [ref(:occurrence_bundler)]
        'pack'  | [ref(:occurrence_npm)]
        'lock'  | [ref(:occurrence_npm), ref(:occurrence_bundler)]
        '_'     | []
      end

      with_them do
        it 'returns records filtered by search' do
          result = described_class.filter_by_search_with_component_and_group(keyword, component_version.id, group)

          expect(result).to match_array(occurrences)
        end
      end
    end

    context 'with no search keyword' do
      let_it_be(:occurrence_bundler_with_no_source) do
        create(:sbom_occurrence, source: nil, component_version: component_version, project: project)
      end

      let(:keyword) { nil }

      it 'returns all relevant records' do
        result = described_class.filter_by_search_with_component_and_group(keyword, component_version.id, group)

        expect(result).to match_array([occurrence_npm, occurrence_bundler, occurrence_bundler_with_no_source])
      end
    end

    context 'with unrelated group' do
      let_it_be(:unrelated_group) { create(:group) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', component_version.id, unrelated_group)
      end

      it { is_expected.to be_empty }
    end

    context 'with unrelated component' do
      let_it_be(:unrelated_component_version) { create(:sbom_component_version) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', unrelated_component_version.id, group)
      end

      it { is_expected.to be_empty }
    end
  end

  describe ".with_licenses" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject { described_class.with_licenses }

    context "without occurrences" do
      it { is_expected.to be_empty }
    end

    context "without a license" do
      let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }

      it { is_expected.to be_empty }
    end

    context "with occurrences" do
      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :mpl_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }
      let_it_be(:occurrence_5) { create(:sbom_occurrence, :mit, :mpl_2, project: project) }
      let_it_be(:occurrence_6) { create(:sbom_occurrence, :apache_2, :mit, project: project) }
      let_it_be(:occurrence_7) { create(:sbom_occurrence, project: project) }

      it "returns an occurrence for each unique license" do
        expect(subject.pluck(:spdx_identifier)).to eq([
          "MIT",
          "MPL-2.0",
          "Apache-2.0",
          "Apache-2.0", "MPL-2.0",
          "MIT", "MPL-2.0",
          "Apache-2.0", "MIT"
        ])
      end
    end

    context "with an expression-only occurrence" do
      let_it_be(:occurrence_expression) { create(:sbom_occurrence, :license_expression, project: project) }

      it "excludes the occurrence because its only license has no spdx identifier" do
        expect(subject).not_to include(occurrence_expression)
      end
    end
  end

  describe '.filter_by_reachability' do
    let(:filter_values) { [:in_use] }

    subject(:filter_by_reachability) { described_class.filter_by_reachability(filter_values) }

    it { is_expected.to be_empty }

    context 'with existing records' do
      let_it_be(:occurrence_in_use) { create(:sbom_occurrence, reachability: :in_use) }
      let_it_be(:occurrence_unknown) { create(:sbom_occurrence, reachability: :unknown) }
      let_it_be(:occurrence_not_found) { create(:sbom_occurrence, reachability: :not_found) }

      it { is_expected.to match_array(occurrence_in_use) }

      context 'with multiple filter values' do
        let(:filter_values) { [:in_use, :not_found] }

        it { is_expected.to match_array([occurrence_in_use, occurrence_not_found]) }
      end
    end
  end

  describe '.filter_by_vulnerability_id' do
    let(:filter_values) { [vulnerability_1.id] }
    let_it_be(:vulnerability_1) { create(:vulnerability) }
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occ_vuln_1) do
      create(:sbom_occurrences_vulnerability, vulnerability: vulnerability_1, occurrence: occurrence_1)
    end

    subject(:filter_by_vulnerability_id) { described_class.filter_by_vulnerability_id(filter_values) }

    it { is_expected.to match_array([occurrence_1]) }

    context 'with unrelated records' do
      let_it_be(:vulnerability_2) { create(:vulnerability) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence) }
      let_it_be(:occ_vuln_2) do
        create(:sbom_occurrences_vulnerability, vulnerability: vulnerability_2, occurrence: occurrence_2)
      end

      it { is_expected.to match_array([occurrence_1]) }
    end
  end

  describe '.for_project' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by project_id' do
      expect(described_class.for_project(occurrence_1.project)).to eq([occurrence_1])
    end
  end

  describe 'group related scopes' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group_1) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: parent_group) }
    let_it_be(:child_group_1_1) { create(:group, parent: child_group_1) }

    let_it_be(:project_on_parent) { create(:project, group: parent_group) }
    let_it_be(:project_on_child_1) { create(:project, group: child_group_1) }
    let_it_be(:project_on_child_2) { create(:project, :archived, group: child_group_2) }
    let_it_be(:project_on_child_1_1) { create(:project, group: child_group_1_1) }

    let_it_be(:occurrence_on_project_on_parent) { create(:sbom_occurrence, project: project_on_parent) }
    let_it_be(:occurrence_on_project_on_child_1) { create(:sbom_occurrence, project: project_on_child_1) }
    let_it_be(:another_occurrence_on_project_on_child_1) { create(:sbom_occurrence, project: project_on_child_1) }
    let_it_be(:occurrence_on_project_on_child_2) { create(:sbom_occurrence, project: project_on_child_2) }
    let_it_be(:occurrence_on_project_on_child_1_1) { create(:sbom_occurrence, project: project_on_child_1_1) }

    describe '.in_parent_group_after_and_including' do
      subject { described_class.in_parent_group_after_and_including(another_occurrence_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          another_occurrence_on_project_on_child_1,
          occurrence_on_project_on_child_2,
          occurrence_on_project_on_child_1_1
        ])
      end
    end

    describe '.in_parent_group_before_and_including' do
      subject { described_class.in_parent_group_before_and_including(another_occurrence_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          occurrence_on_project_on_parent,
          occurrence_on_project_on_child_1,
          another_occurrence_on_project_on_child_1
        ])
      end
    end

    describe '.order_traversal_ids_asc' do
      subject { described_class.order_traversal_ids_asc }

      it do
        is_expected.to eq([
          occurrence_on_project_on_parent,
          occurrence_on_project_on_child_1,
          another_occurrence_on_project_on_child_1,
          occurrence_on_project_on_child_1_1,
          occurrence_on_project_on_child_2
        ])
      end
    end
  end

  describe '.with_dependency_paths_existence' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence) }
    let_it_be(:graph_path_1) { create(:sbom_graph_path, descendant: occurrence_1, ancestor: occurrence_2) }
    let_it_be(:graph_path_2) { create(:sbom_graph_path, descendant: occurrence_3, ancestor: occurrence_2) }

    it 'correctly identifies occurrences with dependency paths' do
      expect(described_class.with_dependency_paths_existence.order_by_id.map(&:has_dependency_paths)).to eq(
        [true, false, true]
      )
    end

    it 'adds has_dependency_paths to attributes' do
      occurrence = described_class.with_dependency_paths_existence.order_by_id.first
      expect(occurrence.attributes.key?('has_dependency_paths')).to be true
    end

    it 'avoids n+1 queries' do
      # control query
      control = ActiveRecord::QueryRecorder.new do
        described_class.with_dependency_paths_existence.map(&:has_dependency_paths)
      end

      # create 2 more occurrences and paths
      2.times do
        occ = create(:sbom_occurrence)
        create(:sbom_graph_path, descendant: occ, ancestor: occurrence_2)
      end

      expect do
        described_class.with_dependency_paths_existence.map(&:has_dependency_paths)
      end.not_to exceed_query_limit(control)
    end
  end

  describe '#name' do
    let(:component) { build(:sbom_component, name: 'rails') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates name to component' do
      expect(occurrence.name).to eq('rails')
    end
  end

  describe '#version' do
    let(:component_version) { build(:sbom_component_version, version: '6.1.6.1') }
    let(:occurrence) { build(:sbom_occurrence, component_version: component_version) }

    it 'delegates version to component_version' do
      expect(occurrence.version).to eq('6.1.6.1')
    end

    context 'when component_version is nil' do
      let(:occurrence) { build(:sbom_occurrence, component_version: nil) }

      it 'returns nil' do
        expect(occurrence.version).to be_nil
      end
    end
  end

  describe '#purl_type' do
    let(:component) { build(:sbom_component, purl_type: 'npm') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates purl_type to component' do
      expect(occurrence.purl_type).to eq('npm')
    end
  end

  describe '#component_type' do
    let(:component) { build(:sbom_component, component_type: 'library') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates component_type to component' do
      expect(occurrence.component_type).to eq('library')
    end
  end

  describe 'source delegation' do
    let(:source_attributes) do
      {
        'category' => 'development',
        'input_file' => { 'path' => 'package-lock.json' },
        'source_file' => { 'path' => 'package.json' },
        'package_manager' => { 'name' => 'npm' },
        'language' => { 'name' => 'JavaScript' }
      }
    end

    let(:source) { build(:sbom_source, source: source_attributes) }
    let(:occurrence) { build(:sbom_occurrence, source: source) }

    describe '#packager' do
      subject(:packager) { occurrence.packager }

      it 'delegates packager to source' do
        expect(packager).to eq('npm')
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it { is_expected.to be_nil }
      end
    end

    describe '#purl' do
      let(:occurrence) { build(:sbom_occurrence, component: component) }

      subject(:purl) { occurrence.purl }

      context 'when component has no purl_type' do
        let(:component) { build(:sbom_component, purl_type: nil) }

        it { is_expected.to be_nil }
      end

      context 'when component has a namspace' do
        let(:component) { build(:sbom_component, purl_type: :maven, name: 'foo/bar/bin') }

        it 'initializes purl with namespace and name' do
          expect(purl).to be_a(::Sbom::PackageUrl)
          expect(purl.type).to eq('maven')
          expect(purl.namespace).to eq('foo/bar')
          expect(purl.name).to eq('bin')
          expect(purl.version).to eq(occurrence.version)
        end
      end

      context 'when component does not have a namespace' do
        let(:component) { build(:sbom_component, purl_type: :maven, name: 'foo') }

        it 'initializes purl without namepsace' do
          expect(purl).to be_a(::Sbom::PackageUrl)
          expect(purl.type).to eq('maven')
          expect(purl.namespace).to be_empty
          expect(purl.name).to eq('foo')
          expect(purl.version).to eq(occurrence.version)
        end
      end
    end

    describe '#location' do
      subject(:location) { occurrence.location }

      it 'returns expected location data' do
        expect(location).to eq(
          {
            blob_path: "/#{occurrence.project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.input_file_path}",
            path: occurrence.input_file_path,
            top_level: false,
            ancestors: []
          }
        )
      end

      context 'when ancestors is present' do
        let(:ancestors) { [{ 'name' => 'name', 'version' => 'version' }] }
        let(:occurrence) { build(:sbom_occurrence, source: source, ancestors: ancestors) }

        it 'returns location data including ancestors' do
          expect(location[:ancestors]).to eq(ancestors)
        end

        context 'when ancestors contains empty hash' do
          let(:ancestors) { [{ 'name' => 'name', 'version' => 'version' }, {}] }

          it 'returns location data including ancestors' do
            expect(location[:ancestors]).to eq(ancestors)
          end

          it 'returns top_level set to true' do
            expect(location[:top_level]).to be true
          end
        end
      end

      context 'when occurrence was found by trivy' do
        before do
          occurrence.input_file_path = 'container-image:photon:5.1-12345678'
        end

        it 'returns expected location data' do
          expect(location).to eq(
            {
              blob_path: "/#{occurrence.project.full_path}/-/blob/#{occurrence.commit_sha}/" \
                         "#{occurrence.input_file_path}",
              path: occurrence.input_file_path,
              top_level: false,
              ancestors: []
            }
          )
        end
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it 'returns nil values' do
          expect(location).to eq(
            {
              blob_path: nil,
              path: nil,
              top_level: false,
              ancestors: []
            }
          )
        end
      end

      context 'when project is nil' do
        # Project shouldn't be nil, but occasionally an SbomOccurrence could be orphaned when
        # a project is deleted.
        # Tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/541931
        let(:occurrence) do
          occurrence = build(:sbom_occurrence)
          occurrence.project = nil
          occurrence
        end

        it 'returns nil for the blob_path' do
          expect(location).to eq(
            {
              blob_path: nil,
              path: occurrence.input_file_path,
              top_level: false,
              ancestors: []
            }
          )
        end
      end
    end
  end

  describe '#malware_status' do
    let_it_be(:occurrence) { build_stubbed(:sbom_occurrence) }

    it 'delegates to Vulnerability.malware_status_for with its vulnerabilities and project' do
      allow(Vulnerability).to receive(:malware_status_for)
        .with(occurrence.vulnerabilities, occurrence.project)
        .and_return(true)

      expect(occurrence.malware_status).to be true
    end

    context 'when malware_vulnerable is set' do
      let_it_be(:group) { build_stubbed(:group) }

      it 'delegates to Vulnerability.malware_status_for with the malware_vulnerable instead of project' do
        occurrence.malware_vulnerable = group

        allow(Vulnerability).to receive(:malware_status_for)
          .with(occurrence.vulnerabilities, group)
          .and_return(false)

        expect(occurrence.malware_status).to be false
      end
    end
  end

  describe '#has_dependency_paths?' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }
    let_it_be(:graph_path_1) { create(:sbom_graph_path, descendant: occurrence_1, ancestor: occurrence_2) }

    it 'returns true if the occurrence is a descendant in sbom_graph_paths' do
      expect(occurrence_1.has_dependency_paths?).to be(true)
    end

    context 'when the attribute is already calculated using with_dependency_paths_existence scope' do
      let_it_be(:occ) { described_class.with_dependency_paths_existence.order_by_id.first }

      it 'does not make additional database queries' do
        expect { occ.has_dependency_paths? }.not_to make_queries_matching(/sbom_graph_paths/)
      end
    end
  end

  context 'with loose foreign key on sbom_occurrences.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:sbom_occurrence, project: parent) }
    end
  end
end
