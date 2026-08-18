# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreatePipelineService, :clean_gitlab_redis_shared_state,
  feature_category: :continuous_integration do
  include ProjectForksHelper

  let_it_be_with_refind(:project) { create(:project, :repository) }

  let(:service) { described_class.new(project: source_project, current_user: user, params: params) }
  let_it_be_with_reload(:user) { create(:user) }
  let(:source_project) { project }
  let(:source_branch) { 'feature' }
  let(:target_project) { project }
  let(:target_branch) { 'master' }
  let(:params) { {} }

  let(:merge_request) do
    create(:merge_request,
      source_project: source_project, source_branch: source_branch,
      target_project: target_project, target_branch: target_branch,
      merge_status: 'unchecked')
  end

  describe '#execute' do
    subject(:result) { service.execute(merge_request) }

    let(:title) { 'Awesome merge request' }
    let(:merge_pipelines_enabled) { true }
    let(:merge_pipelines_license) { true }

    let(:ci_yaml) do
      YAML.dump({
        test: {
          stage: 'test',
          script: 'echo',
          only: ['merge_requests']
        }
      })
    end

    before do
      source_project.add_developer(user)
      target_project.add_developer(user)
      source_project.merge_pipelines_enabled = merge_pipelines_enabled
      stub_licensed_features(merge_pipelines: merge_pipelines_license, multiple_approval_rules: true)
      stub_ci_pipeline_yaml_file(ci_yaml)
    end

    shared_examples_for 'detached merge request pipeline' do
      it 'creates a detached merge request pipeline' do
        result

        expect(merge_request.all_pipelines.count).to eq(1)
        expect(merge_request.all_pipelines.last).not_to be_merged_result_pipeline
        expect(merge_request.all_pipelines.last).to be_detached_merge_request_pipeline
      end

      it 'responds with success', :aggregate_failures do
        expect(result).to be_success
        expect(result.payload).to eq(Ci::Pipeline.last)
      end
    end

    shared_examples_for 'merged result pipeline' do
      it 'creates a merge result pipeline' do
        allow(::Ci::CreatePipelineService).to(receive(:new).with(
          anything, anything, a_hash_including(pipeline_creation_request: nil)
        )).and_call_original

        result

        expect(merge_request.all_pipelines.count).to eq(1)
        expect(merge_request.all_pipelines.last).to be_merged_result_pipeline
        expect(merge_request.all_pipelines.last).not_to be_detached_merge_request_pipeline
      end

      it 'responds with success', :aggregate_failures do
        expect(result).to be_success
        expect(result.payload).to eq(Ci::Pipeline.last)
      end
    end

    context 'when push options contain ci.skip' do
      let(:params) { { push_options: { ci: { skip: true } } } }

      it 'creates a skipped pipeline' do
        result

        expect(merge_request.all_pipelines.count).to eq(1)
        pipeline = merge_request.all_pipelines.last
        expect(pipeline).to be_merged_result_pipeline
        expect(pipeline.builds).to be_empty
        expect(pipeline).to be_skipped
      end
    end

    context 'when mergeability status changes after the ref is updated' do
      before do
        allow_next_instance_of(::MergeRequests::MergeabilityCheckService) do |service|
          allow(service).to(receive(:reload_merge_head_diff)).and_wrap_original do |original|
            # update the merge request via a different record to simulate external race
            MergeRequest.find(merge_request.id).mark_as_unchecked
            original.call
          end
        end
      end

      it_behaves_like 'merged result pipeline'
    end

    context 'when merge request is a draft' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it_behaves_like 'merged result pipeline'
    end

    context 'when merge request requires an approval' do
      before do
        create(:approval_merge_request_rule,
          merge_request: merge_request,
          users: [user],
          name: 'some-custom-rule',
          approvals_required: 1)
      end

      it_behaves_like 'merged result pipeline'
    end

    context 'when project setting for merge request pipelines is disabled' do
      let(:merge_pipelines_enabled) { false }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when merge request is submitted from fork' do
      let(:source_project) { fork_project(project, nil, repository: true) }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when the CreateService is retried' do
      it 'does not create a merge request pipeline twice' do
        expect do
          2.times { service.execute(merge_request) }
        end.to change { Ci::Pipeline.count }.by(1)
      end
    end

    context 'when merge request has no commit' do
      let(:source_branch) { 'empty-branch' }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when merge request has a conflict' do
      let(:source_branch) { 'feature' }
      let(:target_branch) { 'feature_conflict' }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when workflow:rules are specified' do
      let(:source_branch) { 'feature' }
      let(:target_branch) { 'feature_conflict' }

      context 'when bridge job is used' do
        let(:config) do
          {
            workflow: {
              rules: [
                { if: '$CI_MERGE_REQUEST_ID' }
              ]
            },
            bridge_job: {
              needs: { pipeline: 'some/project' }
            }
          }
        end

        it_behaves_like 'detached merge request pipeline'
      end
    end

    context 'when .gitlab-ci.yml is invalid' do
      let(:ci_yaml) { 'invalid yaml file' }

      it 'persists a pipeline with a config error', :aggregate_failures do
        expect { result }.to change { Ci::Pipeline.count }.by(1)
        expect(merge_request.all_pipelines.last).to be_failed
        expect(merge_request.all_pipelines.last).to be_config_error
      end

      it 'responds with error', :aggregate_failures do
        expect(result).to be_error
        expect(result.message).to eq(
          'Cannot create a pipeline for this merge request: duplicate pipeline.'
        )
      end
    end
  end

  describe '#allowed?' do
    using RSpec::Parameterized::TableSyntax

    subject(:allowed) { service.allowed?(merge_request) }

    let(:user) { create(:user) } # shadow: per-example user to avoid memoized access-level cache across with_them rows
    let(:project) { create(:project, :repository) } # shadow: membership varies per with_them row
    let(:merge_pipelines_enabled) { true }
    let(:user_without_permissions) { create(:user) }

    where(:merged_result_pipeline_supported, :detached_mr_pipeline_supported, :user_can_run_pipeline, :result) do
      true  | true  | true  | true
      true  | false | true  | true
      true  | true  | false | false
      true  | false | false | false
      false | true  | true  | true
      false | true  | false | false
      false | false | true  | false
      false | false | false | false
    end

    with_them do
      before do
        allow(service)
          .to receive(:can_create_merged_result_pipeline_for?)
          .with(merge_request)
          .and_return(merged_result_pipeline_supported)

        allow(service)
          .to receive(:can_create_pipeline_for?)
          .with(merge_request)
          .and_return(detached_mr_pipeline_supported)

        project.add_developer(user) if user_can_run_pipeline

        source_project.merge_pipelines_enabled = merge_pipelines_enabled
        stub_licensed_features(merge_pipelines: true)
      end

      it 'matches the expected result' do
        expect(allowed).to eq(result)
      end
    end
  end

  describe '#can_create_merged_result_pipeline_for?' do
    context 'when user can create pipeline and has commits' do
      before do
        allow(service).to receive(:can_create_pipeline_in_target_project?)
          .with(merge_request).and_return(true)
        allow(merge_request).to receive(:has_no_commits?).and_return(false)
      end

      it 'returns true' do
        expect(service.send(:can_create_merged_result_pipeline_for?, merge_request))
          .to be true
      end
    end

    context 'when user cannot create pipeline in target project' do
      before do
        allow(service).to receive(:can_create_pipeline_in_target_project?)
          .with(merge_request).and_return(false)
      end

      it 'returns false' do
        expect(service.send(:can_create_merged_result_pipeline_for?, merge_request))
          .to be false
      end
    end

    context 'when merge request has no commits' do
      before do
        allow(service).to receive(:can_create_pipeline_in_target_project?)
          .with(merge_request).and_return(true)
        allow(merge_request).to receive(:has_no_commits?).and_return(true)
      end

      it 'returns false' do
        expect(service.send(:can_create_merged_result_pipeline_for?, merge_request))
          .to be false
      end
    end
  end
end
