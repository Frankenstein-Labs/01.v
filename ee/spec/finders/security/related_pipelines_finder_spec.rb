# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::RelatedPipelinesFinder, feature_category: :security_policy_management do
  include Ci::SourcePipelineHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:pipeline) do
    create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:push])
  end

  let_it_be(:sha) { pipeline.sha }
  let_it_be(:params) { {} }

  let_it_be(:web_pipeline) do
    create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:web], sha: sha)
  end

  let_it_be(:merge_request_pipeline_1) do
    create(:ci_pipeline, :running,
      project: project,
      source: Enums::Ci::Pipeline.sources[:merge_request_event],
      sha: sha
    )
  end

  let_it_be(:security_policy_pipeline) do
    create(:ci_pipeline, :success,
      project: project,
      source: Enums::Ci::Pipeline.sources[:security_orchestration_policy],
      sha: sha
    )
  end

  let_it_be(:merge_request_pipeline_2) do
    create(:ci_pipeline, :success,
      project: project,
      source: Enums::Ci::Pipeline.sources[:merge_request_event],
      sha: sha
    )
  end

  let_it_be(:web_pipeline_with_different_sha) do
    create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:web], sha: 'sha2')
  end

  describe '#execute' do
    subject { described_class.new(pipeline, params).execute }

    context 'with sources' do
      let(:params) { { sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values } }

      it do
        is_expected.to contain_exactly(pipeline.id, web_pipeline.id, security_policy_pipeline.id,
          merge_request_pipeline_2.id)
      end
    end

    context 'with ref' do
      let(:params) do
        {
          sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values,
          ref: project.default_branch
        }
      end

      let_it_be(:tag_pipeline) do
        create(:ci_pipeline, :success,
          project: project,
          tag: true,
          sha: sha,
          ref: 'tag-v1',
          source: Enums::Ci::Pipeline.sources[:push]
        )
      end

      it do
        is_expected.to contain_exactly(pipeline.id, web_pipeline.id, security_policy_pipeline.id,
          merge_request_pipeline_2.id)
      end
    end

    context 'with merged_result_pipeline' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, :merged_result_pipeline, :success, project: project)
      end

      let_it_be(:push_pipeline) do
        create(:ci_pipeline, :success, sha: sha, project: project, source: Enums::Ci::Pipeline.sources[:push])
      end

      let_it_be(:sha) { pipeline.source_sha }

      it { is_expected.to contain_exactly(pipeline.id, security_policy_pipeline.id, web_pipeline.id, push_pipeline.id) }
    end

    context 'with child pipelines' do
      let_it_be(:child_pipeline_1) { create(:ci_pipeline, project: project, source: :parent_pipeline) }
      let_it_be(:child_pipeline_2) { create(:ci_pipeline, project: project, source: :parent_pipeline) }
      let_it_be(:child_pipeline_3) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

      before do
        create_source_pipeline(pipeline, child_pipeline_1)
        create_source_pipeline(pipeline, child_pipeline_2)
        create_source_pipeline(merge_request_pipeline_2, child_pipeline_3)
      end

      it do
        is_expected.to contain_exactly(
          pipeline.id, web_pipeline.id, security_policy_pipeline.id, merge_request_pipeline_2.id,
          child_pipeline_1.id, child_pipeline_2.id, child_pipeline_3.id
        )
      end
    end

    context 'with limit' do
      let_it_be(:sha) { 'sha' }
      let(:params) { { sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values } }

      let_it_be(:pipeline) do
        create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:push], sha: sha)
      end

      let_it_be(:webide_pipeline) do
        create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:webide], sha: sha)
      end

      let_it_be(:mr_pipeline) do
        create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:merge_request_event],
          sha: sha)
      end

      let_it_be(:security_policy_pipeline) do
        create(:ci_pipeline, :success, project: project,
          source: Enums::Ci::Pipeline.sources[:security_orchestration_policy], sha: sha)
      end

      let_it_be(:child_pipeline_1) { create(:ci_pipeline, project: project, source: :parent_pipeline) }
      let_it_be(:child_pipeline_2) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

      before do
        create_source_pipeline(pipeline, child_pipeline_1)
        create_source_pipeline(webide_pipeline, child_pipeline_2)

        stub_const("#{described_class}::PIPELINES_LIMIT", 4)
      end

      it { is_expected.to match_array([pipeline.id, mr_pipeline.id, security_policy_pipeline.id, child_pipeline_1.id]) }
    end

    context 'with tag pipeline' do
      let_it_be(:sha) { 'tag_sha' }
      let_it_be(:pipeline) do
        create(:ci_pipeline, :success,
          tag: true,
          sha: sha,
          project: project,
          source: Enums::Ci::Pipeline.sources[:push]
        )
      end

      it { is_expected.to be_empty }
    end
  end

  describe '#latest_completed_pipelines_matching_sha' do
    let(:pipelines) { Ci::Pipeline.all }

    it 'calls latest_limited_pipeline_ids_per_source' do
      expect(Ci::Pipeline).to receive(:latest_limited_pipeline_ids_per_source)
        .with(pipelines, pipeline.sha)

      described_class.new(pipeline, {}).send(:latest_completed_pipelines_matching_sha, pipelines)
    end
  end
end
