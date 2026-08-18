# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::RunScheduleWorker, feature_category: :security_policy_management do
  include RepoHelpers

  it 'uses the max time window as deduplication TTL' do
    expect(described_class.get_deduplication_options).to include({ ttl: 1.month, including_scheduled: true })
  end

  describe '#perform' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:ci_config_project) { create(:project, :repository) }
    let_it_be(:security_bot) { create(:user, :security_policy_bot) }
    let_it_be(:policy_ci_filename) { "policy-ci.yml" }
    let_it_be(:security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration)
    end

    let_it_be_with_reload(:security_policy) do
      create(
        :security_policy,
        :pipeline_execution_schedule_policy,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration,
        content: {
          content: { include: [{ project: ci_config_project.full_path, file: policy_ci_filename }] },
          schedules: [{ type: "daily", start_time: "00:00", time_window: { distribution: 'random', value: 4000 } }]
        })
    end

    let_it_be_with_reload(:schedule) do
      create(:security_pipeline_execution_project_schedule, project: project, security_policy: security_policy)
    end

    let_it_be(:ci_config) do
      {
        "scheduled_pep_job_pre" => {
          "stage" => ".pipeline-policy-pre",
          "script" => "exit 0"
        },
        "scheduled_pep_job_post" => {
          "stage" => ".pipeline-policy-post",
          "script" => "exit 0"
        },
        "scheduled_pep_job_test" => {
          "stage" => "test",
          "script" => "exit 0"
        }
      }
    end

    let_it_be(:ci_skip_commit_message) { "[ci skip] foobar" }

    let(:spp_repository_pipeline_access?) { true }
    let(:spp_linked?) { true }
    let(:options) { {} }
    let(:schedule_id) { non_existing_record_id }

    before_all do
      project.add_guest(security_bot)

      create_file_in_repo(
        ci_config_project,
        ci_config_project.default_branch_or_main,
        ci_config_project.default_branch_or_main,
        policy_ci_filename,
        ci_config.to_yaml)

      create_file_in_repo(
        project,
        project.default_branch_or_main,
        project.default_branch_or_main,
        "TEST.md",
        "",
        commit_message: ci_skip_commit_message)
    end

    before do
      ci_config_project.reload.project_setting.update!(spp_repository_pipeline_access: spp_repository_pipeline_access?)

      if spp_linked?
        create(
          :security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: ci_config_project)
      end
    end

    subject(:perform) { described_class.new.perform(schedule_id, options) }

    context 'when schedule exists' do
      let(:schedule_id) { schedule.id }

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(scheduled_pipeline_execution_policies: false)
        end

        it 'does not create a pipeline' do
          expect { perform }.not_to change { project.all_pipelines.count }.from(0)
        end
      end

      it 'creates a pipeline' do
        expect { perform }.to change { project.all_pipelines.count }.from(0).to(1)
      end

      it 'records the policy schedule pipeline association', :aggregate_failures do
        expect { perform }.to change { Security::PolicySchedulePipeline.count }.by(1)

        record = Security::PolicySchedulePipeline.last
        expect(record.security_policy).to eq(security_policy)
        expect(record.project).to eq(project)
        expect(record.pipeline).to eq(project.all_pipelines.last)
      end

      context 'when pipeline creation fails for recording' do
        before do
          allow_next_instance_of(Ci::CreatePipelineService) do |create_pipeline_service|
            allow(create_pipeline_service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Pipeline creation failed')
            )
          end
        end

        it 'does not record the policy schedule pipeline association' do
          expect { perform }.not_to change { Security::PolicySchedulePipeline.count }
        end
      end

      context 'when recording the association fails' do
        before do
          allow(Security::PolicySchedulePipeline).to receive(:create!).and_raise(
            ActiveRecord::RecordInvalid.new(Security::PolicySchedulePipeline.new)
          )
        end

        it 'tracks the exception and does not raise' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)

          expect { perform }.not_to raise_error
        end
      end

      it 'tracks the execution event with successful status', :clean_gitlab_redis_shared_state do
        allow_next_instance_of(Ci::CreatePipelineService) do |create_pipeline_service|
          allow(create_pipeline_service).to receive(:execute).and_return(
            ServiceResponse.success
          )
        end

        expect { perform }
          .to trigger_internal_events('execute_job_scheduled_pipeline_execution_policy')
          .with(
            project: schedule.project,
            additional_properties: { label: 'success' },
            category: 'InternalEventTracking'
          ).and increment_usage_metrics(
            # rubocop:disable Layout/LineLength -- Long metric names
            'redis_hll_counters.count_distinct_namespace_id_from_execute_job_scheduled_pipeline_execution_policy_monthly'
            # rubocop:enable Layout/LineLength
          )
      end

      context 'when project has no security policy bot' do
        before do
          project.team.guests.delete_all
        end

        it 'creates a new bot user' do
          expect { perform }.to change { project.security_policy_bot }.from(nil).to(User)
        end
      end

      describe 'resulting pipeline' do
        subject(:pipeline) { perform.then { project.all_pipelines.last! } }

        it { is_expected.to be_created }

        it "ignores [ci skip]" do
          expect(pipeline.commit.message).to eq(ci_skip_commit_message)
        end

        it "targets the default branch" do
          expect(pipeline.ref).to eq(project.default_branch_or_main)
        end

        it "belongs to policy bot" do
          expect(pipeline.user).to eq(security_bot)
        end

        it "has expected source" do
          expect(pipeline.source).to eq("pipeline_execution_policy_schedule")
        end

        it "contains stages" do
          expect(pipeline.stages.map(&:name)).to match_array(%w[.pipeline-policy-pre test .pipeline-policy-post])
        end

        it "contains builds" do
          expect(pipeline.builds.map(&:name)).to match_array(%w[scheduled_pep_job_pre scheduled_pep_job_test
            scheduled_pep_job_post])
        end

        context 'with branch option' do
          let(:options) { { 'branch' => 'feature-branch' } }

          context 'when the branch does not exist on the project' do
            let(:expected_log) do
              {
                event: Security::PipelineExecutionPolicies::CreateScheduledPipelineService::EVENT_KEY,
                message: "Reference not found",
                reason: nil,
                project_id: schedule.project_id,
                schedule_id: schedule.id,
                policy_id: schedule.security_policy.id,
                branch: 'feature-branch'
              }
            end

            specify do
              expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

              perform
            end

            it 'tracks the execution event with error status', :clean_gitlab_redis_shared_state do
              expect { perform }
                .to trigger_internal_events('execute_job_scheduled_pipeline_execution_policy')
                .with(
                  project: schedule.project,
                  additional_properties: { label: 'error' },
                  category: 'InternalEventTracking'
                ).and increment_usage_metrics(
                  'counts.count_total_errors_in_pipelines_created_from_scheduled_pipeline_execution_policy'
                )
            end
          end

          context 'when the branch exists on the project' do
            before do
              project.repository.add_branch(project.owner, 'feature-branch', project.default_branch_or_main)
            end

            it 'creates a pipeline on the specified branch' do
              expect(pipeline.ref).to eq('feature-branch')
            end
          end
        end
      end

      it "doesn't log" do
        expect(Gitlab::AppJsonLogger).not_to receive(:error)

        perform
      end

      context 'when pipeline creation fails' do
        let(:expected_log) do
          {
            event: Security::PipelineExecutionPolicies::CreateScheduledPipelineService::EVENT_KEY,
            message: a_string_including("Project `#{ci_config_project.full_path}` not found or access denied"),
            reason: nil,
            project_id: schedule.project_id,
            schedule_id: schedule.id,
            policy_id: schedule.security_policy.id,
            branch: 'master'
          }
        end

        shared_examples 'logs the error' do
          specify do
            expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

            perform
          end

          it 'tracks the execution event with error status', :clean_gitlab_redis_shared_state do
            expect { perform }
              .to trigger_internal_events('execute_job_scheduled_pipeline_execution_policy')
              .with(
                project: schedule.project,
                additional_properties: { label: 'error' },
                category: 'InternalEventTracking'
              ).and increment_usage_metrics(
                'counts.count_total_errors_in_pipelines_created_from_scheduled_pipeline_execution_policy'
              )
          end
        end

        context 'with SPP access setting disabled' do
          let(:spp_repository_pipeline_access?) { false }

          it_behaves_like 'logs the error'
        end

        context 'with SPP not linked' do
          let(:spp_linked?) { false }

          it_behaves_like 'logs the error'
        end
      end

      context 'when schedule is snoozed' do
        let_it_be_with_reload(:schedule) do
          create(
            :security_pipeline_execution_project_schedule,
            project: project,
            security_policy: security_policy,
            snoozed_until: Time.zone.now + 1.day
          )
        end

        it 'does not create a pipeline' do
          expect { perform }.not_to change { project.all_pipelines.count }.from(0)
        end

        it 'tracks the snoozed event', :clean_gitlab_redis_shared_state do
          expect { perform }
            .to trigger_internal_events('scheduled_pipeline_execution_policy_snoozed')
            .with(project: schedule.project, category: 'InternalEventTracking')
            .and increment_usage_metrics(
              # rubocop:disable Layout/LineLength -- Long metric names
              'redis_hll_counters.count_distinct_namespace_id_from_execute_job_scheduled_pipeline_execution_policy_snoozed_monthly'
              # rubocop:enable Layout/LineLength
            )
        end
      end
    end

    context 'when schedule does not exist' do
      let(:schedule_id) { non_existing_record_id }

      it 'does not create a pipeline' do
        expect { perform }.not_to change { project.all_pipelines.count }.from(0)
      end
    end

    context 'when options is not a hash' do
      let(:options) { 1 }

      it 'raises an error' do
        expect { perform }.to raise_error(ArgumentError, 'options must be of type Hash')
      end

      context 'and it is nil' do
        let(:options) { nil }

        it 'does not raise an error' do
          expect { perform }.not_to raise_error
        end
      end
    end
  end
end
