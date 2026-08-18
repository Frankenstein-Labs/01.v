# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::TrackResolveDependencyBumpPipelineWorker,
  feature_category: :dependency_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:owner) { project.first_owner }
  let_it_be(:dep_management_sa) do
    create(:user, :service_account, name: 'GitLab Dependency Management').tap do |sa|
      sa.user_detail.update!(provisioned_by_project: project)
      project.add_member(sa, :guest)
    end
  end

  let(:source_branch) { "#{DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/foo-1.x" }

  let(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, author: dep_management_sa,
      source_branch: source_branch)
  end

  let(:workflow_definition) { 'resolve_dependency_bump/experimental' }
  let(:pipeline_status) { :success }

  # A merge-request pipeline: `ref` is refs/merge-requests/<iid>/head, so only `source_ref`
  # resolves it back to the dependency-bump branch.
  let(:pipeline) do
    create(:ci_pipeline, project: project, merge_request: merge_request, status: pipeline_status,
      source: :merge_request_event, ref: merge_request.ref_path)
  end

  let!(:workflow) do
    create(:duo_workflows_workflow,
      project: project,
      user: owner,
      merge_request: merge_request,
      workflow_definition: workflow_definition,
      created_at: pipeline.created_at - 1.hour)
  end

  let(:event) do
    ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: pipeline.status })
  end

  let(:flow_available) { true }

  subject(:handle_event) { described_class.new.handle_event(event) }

  before do
    allow_next_found_instance_of(Project) do |found_project|
      allow(found_project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(flow_available)
    end
  end

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    it 'tracks the generated pipeline outcome as an internal event' do
      expect { handle_event }
        .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
        .with(
          project: project,
          additional_properties: {
            label: 'success',
            value: merge_request.id,
            property: workflow.id.to_s,
            pipeline_id: pipeline.id
          }
        )
        .and increment_usage_metrics(
          'counts.count_total_generate_resolve_dependency_bump_pipeline',
          'counts.count_total_generate_resolve_dependency_bump_pipeline_monthly',
          'counts.count_total_generate_resolve_dependency_bump_pipeline_weekly'
        )
    end

    context 'when the generated pipeline failed' do
      let(:pipeline_status) { :failed }

      it 'records the failed status' do
        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'failed',
              value: merge_request.id,
              property: workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when the pipeline status changed after the event was published' do
      let(:event) do
        ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'failed' })
      end

      it 'records the status carried by the event, not the current pipeline status' do
        expect(pipeline.status).to eq('success')

        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'failed',
              value: merge_request.id,
              property: workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when a branch pipeline runs on the dependency-bump branch' do
      # Built off a real branch so the diff has commits, then renamed, since
      # `all_merge_requests` matches a branch pipeline by source branch *and* sha.
      let(:merge_request) do
        create(:merge_request, source_project: project, target_project: project,
          author: dep_management_sa).tap { |mr| mr.update_column(:source_branch, source_branch) }
      end

      let(:pipeline) do
        create(:ci_pipeline, project: project, status: pipeline_status, ref: source_branch,
          sha: merge_request.diff_head_sha)
      end

      it 'resolves the merge request through source_ref and tracks the outcome' do
        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'success',
              value: merge_request.id,
              property: workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when several workflows ran before the pipeline' do
      let!(:latest_workflow) do
        create(:duo_workflows_workflow,
          project: project,
          user: owner,
          merge_request: merge_request,
          workflow_definition: workflow_definition,
          created_at: pipeline.created_at - 1.minute)
      end

      it 'attributes the pipeline to the most recent one' do
        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'success',
              value: merge_request.id,
              property: latest_workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when the merge request source branch is not a dependency-bump branch' do
      let(:source_branch) { 'some-feature-branch' }

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when a branch pipeline ref is not a dependency-bump branch' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :success, ref: 'some-branch')
      end

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when no opened merge request is authored by the dependency bump service account' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :success,
          ref: "#{DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/unrelated-9.x")
      end

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the merge request was merged before the worker ran' do
      let(:merge_request) do
        create(:merge_request, :merged, source_project: project, target_project: project,
          author: dep_management_sa, source_branch: source_branch)
      end

      it 'still tracks, since a passing pipeline is what unblocks the merge' do
        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'success',
              value: merge_request.id,
              property: workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when no resolve_dependency_bump workflow ran for the merge request' do
      let!(:workflow) { nil }

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the only workflow for the merge request is a different flow' do
      let(:workflow_definition) { 'convert_to_gitlab_ci/experimental' }

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the only workflow was created after the pipeline' do
      let!(:workflow) do
        create(:duo_workflows_workflow,
          project: project,
          user: owner,
          merge_request: merge_request,
          workflow_definition: workflow_definition,
          created_at: pipeline.created_at + 1.hour)
      end

      it 'does not track, since the pipeline predates the flow' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the flow is not available for the project' do
      let(:flow_available) { false }

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the event carries a partition_id' do
      let(:event) do
        ::Ci::PipelineFinishedEvent.new(
          data: { pipeline_id: pipeline.id, status: pipeline.status, partition_id: pipeline.partition_id }
        )
      end

      it 'finds the pipeline within its partition and tracks' do
        expect { handle_event }
          .to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
          .with(
            project: project,
            additional_properties: {
              label: 'success',
              value: merge_request.id,
              property: workflow.id.to_s,
              pipeline_id: pipeline.id
            }
          )
      end
    end

    context 'when the event carries a partition_id the pipeline is not in' do
      let(:event) do
        ::Ci::PipelineFinishedEvent.new(
          data: { pipeline_id: pipeline.id, status: pipeline.status, partition_id: pipeline.partition_id + 1 }
        )
      end

      it 'does not track, since the lookup is scoped to the partition' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end

    context 'when the pipeline does not exist' do
      let(:event) do
        ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: non_existing_record_id, status: 'success' })
      end

      it 'does not track' do
        expect { handle_event }.not_to trigger_internal_events('generate_resolve_dependency_bump_pipeline')
      end
    end
  end
end
