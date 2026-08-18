# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicySchedulePipeline, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
    it { is_expected.to belong_to(:pipeline).class_name('Ci::Pipeline') }
    it { is_expected.to belong_to(:project) }

    describe '#pipeline' do
      it_behaves_like 'a partition-pruned pipeline association' do
        # .reload clears the :pipeline target cached by the attribute writer
        let(:related_resource) { create(:security_policy_schedule_pipeline, pipeline: pipeline).reload }
      end
    end
  end

  describe 'scopes' do
    describe '.for_policy' do
      let_it_be(:policy1) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:policy2) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:record1) { create(:security_policy_schedule_pipeline, security_policy: policy1) }
      let_it_be(:record2) { create(:security_policy_schedule_pipeline, security_policy: policy2) }

      it 'returns records for the given policy' do
        expect(described_class.for_policy(policy1)).to contain_exactly(record1)
      end
    end

    describe '.for_project' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }
      let_it_be(:record1) { create(:security_policy_schedule_pipeline, project: project1) }
      let_it_be(:record2) { create(:security_policy_schedule_pipeline, project: project2) }

      it 'returns records for the given project' do
        expect(described_class.for_project(project1)).to contain_exactly(record1)
      end
    end
  end

  describe '.cancelable_pipelines_for' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:running_pipeline) { create(:ci_pipeline, :running, project: project) }
    let_it_be(:success_pipeline) { create(:ci_pipeline, :success, project: project) }

    let_it_be(:running_record) do
      create(:security_policy_schedule_pipeline,
        security_policy: security_policy,
        pipeline: running_pipeline,
        project: project)
    end

    let_it_be(:success_record) do
      create(:security_policy_schedule_pipeline,
        security_policy: security_policy,
        pipeline: success_pipeline,
        project: project)
    end

    it 'returns only cancelable pipelines for the policy and project' do
      result = described_class.cancelable_pipelines_for(
        security_policy: security_policy,
        project: project
      )

      expect(result).to contain_exactly(running_pipeline)
    end

    it 'returns empty relation when no cancelable pipelines exist' do
      other_project = create(:project)

      result = described_class.cancelable_pipelines_for(
        security_policy: security_policy,
        project: other_project
      )

      expect(result).to be_empty
    end
  end

  describe 'validations' do
    subject { build(:security_policy_schedule_pipeline) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:pipeline) }
    it { is_expected.to validate_presence_of(:project) }

    describe 'uniqueness of pipeline' do
      let_it_be(:existing_record) { create(:security_policy_schedule_pipeline) }

      it 'validates uniqueness of pipeline' do
        new_record = build(:security_policy_schedule_pipeline, pipeline: existing_record.pipeline)

        expect(new_record).not_to be_valid
        expect(new_record.errors[:pipeline]).to include('has already been taken')
      end
    end
  end

  describe '.preload_pipeline' do
    let_it_be(:record) { create(:security_policy_schedule_pipeline) }

    it 'preloads the pipeline association without a per-record query' do
      result = described_class.preload_pipeline.to_a

      expect(result).to contain_exactly(record)
      expect(result.first.association(:pipeline)).to be_loaded
      expect { result.first.pipeline }.not_to exceed_query_limit(0)
    end
  end

  describe '.preload_pipeline_and_project_route' do
    let_it_be(:record) { create(:security_policy_schedule_pipeline) }

    it 'preloads pipeline, project and route' do
      result = described_class.preload_pipeline_and_project_route.to_a

      expect(result).to contain_exactly(record)
      expect(result.first.association(:pipeline)).to be_loaded
      expect(result.first.association(:project)).to be_loaded
      expect(result.first.project.association(:route)).to be_loaded
    end
  end

  describe '.order_by_id_desc' do
    let_it_be(:record) { create(:security_policy_schedule_pipeline) }

    it 'orders by id descending' do
      record2 = create(:security_policy_schedule_pipeline)

      result = described_class.order_by_id_desc

      expect(result.to_a).to eq([record2, record])
    end
  end

  describe '.safe_create' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

    it 'creates a record' do
      expect { described_class.safe_create(security_policy: policy, pipeline: pipeline, project: project) }
        .to change { described_class.count }.by(1)
    end

    context 'when the record is invalid' do
      it 'tracks the exception and does not raise' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(ActiveRecord::RecordInvalid),
          security_policy_id: policy.id,
          pipeline_id: pipeline.id
        )

        expect { described_class.safe_create(security_policy: policy, pipeline: pipeline, project: nil) }
          .not_to raise_error
      end
    end

    context 'when the record already exists' do
      before do
        described_class.safe_create(security_policy: policy, pipeline: pipeline, project: project)
      end

      it 'does not raise an error' do
        expect { described_class.safe_create(security_policy: policy, pipeline: pipeline, project: project) }
          .not_to raise_error
      end

      it 'does not create a duplicate record' do
        expect { described_class.safe_create(security_policy: policy, pipeline: pipeline, project: project) }
          .not_to change { described_class.count }
      end
    end

    context 'when a race condition triggers RecordNotUnique' do
      before do
        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it 'returns nil and does not raise' do
        result = described_class.safe_create(security_policy: policy, pipeline: pipeline, project: project)

        expect(result).to be_nil
      end
    end
  end
end
