# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreateDownstreamPipelineService, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:upstream_project) { create(:project, :repository) }
  let_it_be_with_reload(:upstream_pipeline) { create(:ci_pipeline, :created, project: upstream_project) }

  let(:trigger) do
    {
      trigger: {
        project: downstream_project.full_path,
        branch: 'feature'
      }
    }
  end

  let(:bridge) do
    create(
      :ci_bridge,
      status: :pending,
      user: user,
      options: trigger,
      pipeline: upstream_pipeline
    )
  end

  let(:service) { described_class.new(upstream_project, user) }

  let(:pipeline) { execute.payload }

  subject(:execute) { service.execute(bridge) }

  describe 'audit events' do
    before do
      stub_ci_pipeline_yaml_file(YAML.dump(rspec: { script: 'rspec' }))
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when multi project downstream pipeline is created' do
      let_it_be(:downstream_project) { create(:project, :repository) }

      before_all do
        upstream_project.add_developer(user)
        downstream_project.add_developer(user)
      end

      it 'calls auditor with correct args' do
        execute

        expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: "multi_project_downstream_pipeline_created",
          author: user,
          scope: pipeline.project,
          target: pipeline,
          target_details: pipeline.id.to_s,
          message: "Multi-project downstream pipeline created.",
          additional_details: {
            upstream_root_pipeline_id: upstream_pipeline.id,
            upstream_root_project_path: upstream_pipeline.project.full_path
          }
        )
      end
    end

    context 'when parent child project downstream pipeline is created' do
      let_it_be(:downstream_project) { upstream_project }

      before_all do
        upstream_project.add_developer(user)
        downstream_project.add_developer(user)
      end

      it 'does not calls auditor' do
        execute

        expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
      end
    end
  end

  describe 'security policy bot child pipeline permissions' do
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    let(:trigger) do
      {
        trigger: { include: 'child-pipeline.yml' }
      }
    end

    let(:bridge) do
      create(
        :ci_bridge,
        status: :pending,
        user: security_policy_bot,
        options: trigger,
        pipeline: upstream_pipeline
      )
    end

    let(:service) { described_class.new(upstream_project, security_policy_bot) }

    before_all do
      upstream_project.add_guest(security_policy_bot)
    end

    before do
      stub_ci_pipeline_yaml_file(YAML.dump(rspec: { script: 'rspec' }))
    end

    context 'when security policy bot triggers a child pipeline' do
      it 'allows the bot to create the child pipeline' do
        expect(execute).to be_success
        expect(pipeline).to be_created_successfully
      end
    end

    context 'when security policy bot triggers a multi-project pipeline' do
      let_it_be(:downstream_project) { create(:project, :repository) }

      let(:trigger) do
        {
          trigger: {
            project: downstream_project.full_path,
            branch: 'main'
          }
        }
      end

      it 'fails because bot cannot read downstream project without job token scope' do
        expect(execute).to be_error
        expect(bridge.reload.failure_reason).to eq('downstream_bridge_project_not_found')
      end
    end

    context 'when non-bot user without push access triggers a child pipeline' do
      let_it_be(:guest_user) { create(:user) }

      let(:bridge) do
        create(
          :ci_bridge,
          status: :pending,
          user: guest_user,
          options: trigger,
          pipeline: upstream_pipeline
        )
      end

      let(:service) { described_class.new(upstream_project, guest_user) }

      before_all do
        upstream_project.add_guest(guest_user)
      end

      it 'fails with insufficient permissions' do
        expect(execute).to be_error
        expect(bridge.reload.failure_reason).to eq('insufficient_bridge_permissions')
      end
    end
  end

  describe 'pipeline execution policies enforced in child pipelines' do
    include RepoHelpers

    let(:file_content) do
      YAML.dump(
        rspec: { script: 'rspec' },
        echo: { script: 'echo' })
    end

    let(:trigger) do
      {
        trigger: { include: 'child-pipeline.yml' }
      }
    end

    let_it_be_with_reload(:compliance_project) { create(:project, :empty_repo) }
    let(:policy_content) { { policy_job: { script: 'project script' } } }
    let(:policy_file) { 'project-policy.yml' }
    let(:policy) do
      build(:pipeline_execution_policy,
        content: { include: [{
          project: compliance_project.full_path,
          file: policy_file,
          ref: compliance_project.default_branch_or_main
        }] })
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, pipeline_execution_policy: [policy])
    end

    let(:experiment_enabled) { true }
    let_it_be_with_reload(:policies_project) { create(:project, :empty_repo) }
    let!(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        experiments: { enforce_pipeline_policy_on_child_pipelines: { enabled: experiment_enabled } },
        project: upstream_project, security_policy_management_project: policies_project)
    end

    let(:test_stage) { pipeline.stages.find_by(name: 'test') }

    before_all do
      upstream_project.add_developer(user)
      compliance_project.add_developer(user)
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    around do |example|
      create_and_delete_files(
        upstream_project, { 'child-pipeline.yml' => file_content }
      ) do
        upstream_pipeline.update!(sha: upstream_project.commit.id)
        create_and_delete_files(
          policies_project, { '.gitlab/security-policies/policy.yml' => policy_yaml }
        ) do
          create_and_delete_files(
            compliance_project, {
              policy_file => policy_content.to_yaml
            }
          ) do
            example.run
          end
        end
      end
    end

    it 'creates the pipeline with the policy jobs injected' do
      expect { execute }.to change { Ci::Pipeline.count }.by(1)
      expect(execute).to be_success

      expect(test_stage.builds.map(&:name)).to include('policy_job')
    end

    shared_examples_for 'pipeline created without policy jobs injected' do
      it 'creates the pipeline without policy jobs injected' do
        expect { execute }.to change { Ci::Pipeline.count }.by(1)
        expect(execute).to be_success

        expect(test_stage.builds.map(&:name)).not_to include('policy_job')
      end
    end

    context 'when the bridge job was triggered by a policy' do
      let(:bridge) do
        create(
          :ci_bridge,
          status: :pending,
          user: user,
          options: trigger,
          pipeline: upstream_pipeline,
          job_source: build(:ci_build_source, source: 'pipeline_execution_policy')
        )
      end

      it_behaves_like 'pipeline created without policy jobs injected'
    end

    context 'when the experimental feature is not enabled' do
      let(:experiment_enabled) { false }

      it_behaves_like 'pipeline created without policy jobs injected'
    end
  end
end
