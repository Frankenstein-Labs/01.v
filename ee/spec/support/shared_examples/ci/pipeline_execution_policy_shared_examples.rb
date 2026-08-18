# frozen_string_literal: true

RSpec.shared_context 'with pipeline policy context' do
  let(:sha_context) do
    Gitlab::Ci::Pipeline::ShaContext.new(
      before: command.before_sha,
      after: command.after_sha,
      source: command.source_sha,
      checkout: command.checkout_sha,
      target: command.target_sha
    )
  end

  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(
      project: project,
      source: command.source,
      current_user: command.current_user,
      ref: command.ref,
      sha_context: sha_context,
      variables_attributes: command.variables_attributes,
      chat_data: command.chat_data,
      merge_request: command.merge_request,
      schedule: command.schedule
    )
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project, origin_ref: project.default_branch_or_main)
  end

  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let(:creating_policy_pipeline) { false }
  let(:current_policy) do
    FactoryBot.build(:pipeline_execution_policy_config, policy_sha: policy_config_sha,
      policy: FactoryBot.build(:pipeline_execution_policy, name: 'Policy'))
  end

  let(:execution_policy_pipelines) { [] }
  let(:policy_config_sha) { 'config_sha' }
  let(:policy_project_id) { current_policy.policy_config.security_policy_management_project_id }

  before do
    allow(pipeline_policy_context.pipeline_execution_context).to receive_messages(
      creating_policy_pipeline?: creating_policy_pipeline,
      policy_pipelines: execution_policy_pipelines,
      current_policy: creating_policy_pipeline ? current_policy : nil
    )
  end
end

RSpec.shared_examples 'creates PEP project schedules' do
  context "when policy isn't a pipeline execution schedule policy" do
    let_it_be(:security_policy, freeze: false) { create(:security_policy, :scan_execution_policy) }

    it "doesn't create project schedules" do
      expect { execute }.not_to change { Security::PipelineExecutionProjectSchedule.count }
    end
  end

  context 'when policy is a pipeline execution schedule policy' do
    let_it_be_with_reload(:security_policy) do
      create(
        :security_policy,
        :pipeline_execution_schedule_policy,
        content: {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedules: [
            { type: 'weekly',
              days: %w[Monday Sunday],
              start_time: "23:15",
              time_window: {
                distribution: 'random',
                value: 18.hours.to_i
              },
              timezone: "Europe/Berlin" }
          ]
        }
      )
    end

    it 'creates project schedules' do
      expect { execute }.to change { Security::PipelineExecutionProjectSchedule.count }.by(1)
    end

    describe 'persisted project schedules', time_travel_to: '2025-01-01 00:00:00' do # Wed, Jan 25th
      let(:expected_schedule_attributes) do
        {
          cron: "15 23 * * 1,0",
          cron_timezone: "Europe/Berlin", # 1 hour ahead of UTC
          time_window_seconds: 18.hours.to_i,
          next_run_at: Time.zone.parse("2025-01-05 22:15:00"), # Sun, Jan 05th
          project_id: project.id,
          security_policy_id: security_policy.id
        }
      end

      specify do
        allow(Random).to receive(:rand).and_return(0)

        execute

        project_schedule = security_policy.security_pipeline_execution_project_schedules.sole

        expect(project_schedule).to have_attributes(expected_schedule_attributes)
      end
    end

    context 'when the execution fails' do
      let(:invalid_schedule) do
        { type: 'daily',
          start_time: "00:00",
          time_window: {
            distribution: 'random',
            value: -1
          } }
      end

      let(:error_message) { a_string_including('Time window seconds must be greater than or equal to 600') }

      before do
        security_policy.content = security_policy.content.merge(schedules: [invalid_schedule])
        security_policy.save!(validate: false)
      end

      it 'reraises' do
        expect { execute }.to raise_error(ActiveRecord::RecordInvalid, error_message)
                                .and not_change { Security::PipelineExecutionProjectSchedule.count }.from(0)
      end
    end
  end
end
