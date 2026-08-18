# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Statistic, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required(true) }
    it { is_expected.to belong_to(:pipeline).required(false) }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:critical).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:high).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:medium).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:low).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unknown).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:info).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:traversal_ids) }
    it { is_expected.to validate_length_of(:traversal_ids).is_at_least(1) }

    it { is_expected.to define_enum_for(:letter_grade).with_values(%i[a b c d f]) }
  end

  describe '.before_save' do
    describe '#assign_letter_grade' do
      let_it_be(:pipeline) { create(:ci_pipeline) }
      let_it_be_with_reload(:project) { pipeline.project }

      let(:statistic) { build(:vulnerability_statistic, letter_grade: nil, critical: 5, project: project) }

      subject(:save_statistic) { statistic.save! }

      it 'assigns the letter_grade' do
        expect { save_statistic }.to change { statistic.letter_grade }.from(nil).to('f')
      end
    end
  end

  describe '.by_grade' do
    let!(:statistic_grade_a) { create(:vulnerability_statistic, letter_grade: :a) }

    subject { described_class.by_grade(:a) }

    before do
      %w[b c d f].each { create(:vulnerability_statistic, :"grade_#{_1}") }
    end

    it { is_expected.to match_array([statistic_grade_a]) }
  end

  describe '.by_group' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_1_1) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_1_1) { create(:project, group: group_1_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
    let_it_be(:vulnerability_statistic_1_1) { create(:vulnerability_statistic, project: project_1_1) }
    let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

    subject { described_class.by_group(group_1) }

    it 'returns all records within the group hierarchy' do
      is_expected.to contain_exactly(vulnerability_statistic_1, vulnerability_statistic_1_1)
    end
  end

  describe '.by_group_excluding_subgroups' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_1_1) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_1_1) { create(:project, group: group_1_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
    let_it_be(:vulnerability_statistic_1_1) { create(:vulnerability_statistic, project: project_1_1) }
    let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

    subject { described_class.by_group_excluding_subgroups(group_1) }

    it 'returns all records within the group hierarchy' do
      is_expected.to contain_exactly(vulnerability_statistic_1)
    end
  end

  describe '.unarchived' do
    let_it_be(:active_project) { create(:project) }
    let_it_be(:archived_project) { create(:project, :archived) }
    let_it_be(:archived_vulnerability_statistic) { create(:vulnerability_statistic, project: archived_project) }
    let_it_be(:unarchived_vulnerability_statistic) { create(:vulnerability_statistic, project: active_project) }

    subject(:unarchived) { described_class.unarchived }

    it { is_expected.to contain_exactly(unarchived_vulnerability_statistic) }
  end

  describe '.letter_grade_for' do
    subject { described_class.letter_grade_for(object) }

    context 'when the given object is an instance of Vulnerabilities::Statistic' do
      let(:object) { build(:vulnerability_statistic, critical: 1) }

      it { is_expected.to eq(4) }
    end

    context 'when the given object is a Hash' do
      let(:object) { { 'high' => 1 } }

      it { is_expected.to eq(3) }
    end
  end

  describe '.letter_grade_sql_for' do
    using RSpec::Parameterized::TableSyntax

    where(:target_critical, :target_unknown, :target_high, :target_medium, :target_low, :excluded_critical, :excluded_unknown, :excluded_high, :excluded_medium, :excluded_low) do
      0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0

      0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1
      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0
      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1

      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 1
      0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 1
      0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1

      0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1
      0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 1
      0 | 0 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1

      0 | 0 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1
      0 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1
      0 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1

      0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1
      1 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1
      1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1
    end

    with_them do
      let(:target) { "(#{target_critical}, #{target_unknown}, #{target_high}, #{target_medium}, #{target_low})" }
      let(:excluded) { "(#{excluded_critical}, #{excluded_unknown}, #{excluded_high}, #{excluded_medium}, #{excluded_low})" }
      let(:object) do
        {
          critical: target_critical + excluded_critical,
          uknown: target_unknown + excluded_unknown,
          high: target_high + excluded_high,
          medium: target_medium + excluded_medium,
          low: target_low + excluded_low
        }.stringify_keys
      end

      let(:letter_grade_sql) { described_class.letter_grade_sql_for(target, excluded) }
      let(:letter_grade_on_db) { described_class.connection.execute(letter_grade_sql).first['letter_grade'] }
      let(:letter_grade_on_app) { described_class.letter_grade_for(object) }

      it 'matches the application layer logic' do
        expect(letter_grade_on_db).to eq(letter_grade_on_app)
      end
    end
  end

  describe '.ordered_by_severity' do
    it 'orders by critical count when critical differs' do
      higher_stat = create(:vulnerability_statistic, project: create(:project), critical: 5)

      lower_stat = create(:vulnerability_statistic, project: create(:project), critical: 2, high: 10)

      result = described_class
                 .where(id: [higher_stat.id, lower_stat.id])
                 .ordered_by_severity

      expect(result.first.project_id).to eq(higher_stat.project_id)
    end

    it 'orders by high count when critical is equal' do
      higher_stat = create(:vulnerability_statistic, project: create(:project), critical: 3, high: 7)

      lower_stat = create(:vulnerability_statistic, project: create(:project), critical: 3, high: 2)

      result = described_class
                 .where(id: [lower_stat.id, higher_stat.id])
                 .ordered_by_severity

      expect(result.first.project_id).to eq(higher_stat.project_id)
    end

    it 'orders by project_id when all severity counts are equal' do
      project_1 = create(:project)
      project_2 = create(:project)

      stat_1 = create(:vulnerability_statistic, project: project_1)

      stat_2 = create(:vulnerability_statistic, project: project_2)

      result = described_class
                 .where(id: [stat_1.id, stat_2.id])
                 .ordered_by_severity

      expect(result.map(&:project_id)).to eq([project_1.id, project_2.id].sort)
    end

    it 'works when there is only one record' do
      stat = create(:vulnerability_statistic,
        project: create(:project),
        critical: 2,
        high: 1
      )

      result = described_class
                 .where(id: stat.id)
                 .ordered_by_severity

      expect(result).to contain_exactly(an_object_having_attributes(
        project_id: stat.project_id,
        critical: stat.critical,
        high: stat.high
      ))
    end
  end

  describe '.aggregate_by_grade' do
    let_it_be(:project_1) { create(:project) }
    let_it_be(:project_2) { create(:project) }
    let_it_be(:project_3) { create(:project) }

    let_it_be(:stat_a) { create(:vulnerability_statistic, project: project_1, letter_grade: :a) }

    let_it_be(:stat_b1) { create(:vulnerability_statistic, project: project_2, letter_grade: :b, low: 1) }

    let_it_be(:stat_b2) { create(:vulnerability_statistic, project: project_3, letter_grade: :b, low: 2) }

    it 'groups by letter_grade' do
      result = described_class.unarchived.aggregate_by_grade.load
      aggregated = result.index_by(&:letter_grade)

      expect(aggregated.keys).to contain_exactly('a', 'b')

      expect(aggregated['a'].project_ids).to match_array([project_1.id])

      expect(aggregated['b'].project_ids).to match_array([project_2.id, project_3.id])
    end
  end

  describe '.from_statistics' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:statistic) do
      create(:vulnerability_statistic,
        project: project,
        letter_grade: :c,
        critical: 1,
        high: 2,
        medium: 3,
        low: 4,
        unknown: 0,
        info: 0
      )
    end

    it 'returns a relation built from the SQL of the given relation' do
      ordered_scope = described_class.ordered_by_severity
      # The select('*') was added to solve issue encountered when setting ignore_columns
      # by adding adding select('*') we force rails to select all returned columns instead
      # all columns - the ignored columns which caused the query to fail because the query
      # wasn't returning all the columns
      # This should be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/578863
      from_stats = described_class.from_statistics(ordered_scope).select('*')

      result = from_stats.first

      expect(result.project_id).to eq(statistic.project_id)
      expect(result.letter_grade).to eq(statistic.letter_grade)
      expect(result.critical).to eq(statistic.critical)
    end

    it 'raises an error when called with a non-AR relation' do
      expect do
        described_class.from_statistics(["not an AR relation"])
      end.to raise_error(ArgumentError, /Expected ActiveRecord::Relation/)
    end
  end

  describe '.array_agg_ordered_by_severity' do
    it 'returns a SQL snippet for array aggregation' do
      sql = described_class.array_agg_ordered_by_severity.to_s

      expect(sql).to include('array_agg')
      expect(sql).to include('project_id')
      expect(sql).to include('ORDER BY')
    end
  end

  describe 'consistency between singular and bulk upsert' do
    let_it_be_with_reload(:project) { create(:project, :small_repo) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }
    let(:dynamic_attributes) { [:id, :created_at, :updated_at] }

    it 'sets the same fields with the same values in both methods' do
      described_class.set_latest_pipeline_with(pipeline)
      single_upsert_attributes = described_class.find_by(project_id: pipeline.project_id).attributes.except(dynamic_attributes)

      described_class.delete_all

      described_class.bulk_set_latest_pipelines_with([pipeline])
      bulk_record_attributes = described_class.find_by(project_id: pipeline.project_id).attributes.except(dynamic_attributes)

      expect(single_upsert_attributes.except('id')).to eq(bulk_record_attributes.except('id'))
    end
  end

  describe '.set_latest_pipeline_with' do
    let_it_be_with_reload(:project) { create(:project, :small_repo) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }

    subject(:set_latest_pipeline) { described_class.set_latest_pipeline_with(pipeline) }

    context 'when there is already a vulnerability_statistic record available for the project of given pipeline' do
      let(:vulnerability_statistic) { create(:vulnerability_statistic, project: project) }

      it 'updates the `latest_pipeline_id` attribute of the existing record' do
        expect { set_latest_pipeline }.to change { vulnerability_statistic.reload.pipeline }.from(nil).to(pipeline)
      end
    end

    context 'when there is no vulnerability_statistic record available for the project of given pipeline' do
      before do
        project.update!(archived: true)
      end

      it 'creates a new record where latest_pipeline_id, archived, and traversal_ids are set' do
        expect { set_latest_pipeline }.to change { project.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
                                      .and change { project.vulnerability_statistic&.pipeline }.from(nil).to(pipeline)
                                      .and change { project.vulnerability_statistic&.archived }.from(nil).to(project.archived)
                                      .and change { project.vulnerability_statistic&.traversal_ids }.from(nil).to(project.namespace.traversal_ids)
      end
    end

    context 'when the pipeline is not for the default branch' do
      let_it_be(:non_default_pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      subject(:set_latest_pipeline) { described_class.set_latest_pipeline_with(non_default_pipeline) }

      context 'when there is no vulnerability_statistic record for the project' do
        it 'does not create a vulnerability_statistic record' do
          expect { set_latest_pipeline }.not_to change { project.reload.vulnerability_statistic }
        end
      end

      context 'when there is an existing vulnerability_statistic record for the project' do
        let!(:vulnerability_statistic) { create(:vulnerability_statistic, project: project) }

        it 'does not update the `latest_pipeline_id` attribute of the existing record' do
          expect { set_latest_pipeline }.not_to change { vulnerability_statistic.reload.latest_pipeline_id }
        end
      end
    end
  end

  describe '.bulk_set_latest_pipelines_with' do
    let_it_be(:project_1) { create(:project, :small_repo) }
    let_it_be(:project_2) { create(:project, :small_repo) }
    let_it_be(:pipelines) do
      [
        create(:ci_pipeline, project: project_1, ref: project_1.default_branch),
        create(:ci_pipeline, project: project_2, ref: project_2.default_branch)
      ]
    end

    subject(:bulk_set_latest_pipelines) { described_class.bulk_set_latest_pipelines_with(pipelines) }

    context 'when there is already a vulnerability_statistic record available for the project of given pipeline' do
      let(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
      let(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

      it 'updates the `latest_pipeline_id` attribute of the existing record' do
        expect { bulk_set_latest_pipelines }
          .to change { vulnerability_statistic_1.reload.pipeline }.from(nil).to(pipelines.first)
          .and change { vulnerability_statistic_2.reload.pipeline }.from(nil).to(pipelines.second)
      end
    end

    context 'when there is no vulnerability_statistic record available for the project of given pipeline' do
      it 'creates a new record with the `latest_pipeline_id` attribute is set' do
        expect { bulk_set_latest_pipelines }
          .to change { project_1.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
          .and change { project_1.reload.vulnerability_statistic&.pipeline }.from(nil).to(pipelines.first)
          .and change { project_2.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
          .and change { project_2.reload.vulnerability_statistic&.pipeline }.from(nil).to(pipelines.second)

        expect(project_1.vulnerability_statistic.archived).to eq(project_1.archived)
        expect(project_1.vulnerability_statistic.traversal_ids).to eq(project_1.namespace.traversal_ids)
        expect(project_2.vulnerability_statistic.archived).to eq(project_2.archived)
        expect(project_2.vulnerability_statistic.traversal_ids).to eq(project_2.namespace.traversal_ids)
      end
    end

    context 'when some pipelines are not for the default branch' do
      let_it_be(:non_default_pipeline) { create(:ci_pipeline, project: project_2, ref: 'feature-branch') }

      subject(:bulk_set_latest_pipelines) do
        described_class.bulk_set_latest_pipelines_with([pipelines.first, non_default_pipeline])
      end

      it 'only upserts records for default-branch pipelines' do
        expect { bulk_set_latest_pipelines }
          .to change { project_1.reload.vulnerability_statistic&.pipeline }.from(nil).to(pipelines.first)
          .and not_change { project_2.reload.vulnerability_statistic }
      end
    end

    context 'when no pipelines are for the default branch' do
      let_it_be(:non_default_pipeline_1) { create(:ci_pipeline, project: project_1, ref: 'feature-1') }
      let_it_be(:non_default_pipeline_2) { create(:ci_pipeline, project: project_2, ref: 'feature-2') }

      subject(:bulk_set_latest_pipelines) do
        described_class.bulk_set_latest_pipelines_with([non_default_pipeline_1, non_default_pipeline_2])
      end

      it 'does not create any vulnerability_statistic records' do
        expect { bulk_set_latest_pipelines }
          .to not_change { project_1.reload.vulnerability_statistic }
          .and not_change { project_2.reload.vulnerability_statistic }
      end
    end
  end

  context 'loose foreign key on vulnerability_statistics.latest_pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:vulnerability_statistic, pipeline: parent) }
    end
  end

  context 'with loose foreign key on vulnerability_statistics.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_statistic, project: parent) }
    end
  end

  describe '#pipeline' do
    it_behaves_like 'a partition-pruned pipeline association' do
      let(:related_resource) { create(:vulnerability_statistic, latest_pipeline_id: pipeline.id) }
    end
  end
end
