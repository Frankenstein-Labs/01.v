# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, '#execute', :saas, feature_category: :continuous_integration do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:ultimate_plan) { create(:ultimate_plan) }
  let_it_be_with_reload(:plan_limits) { create(:plan_limits, plan: ultimate_plan) }
  let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace) }
  let_it_be(:user) { create(:user) }

  let(:ref_name) { 'master' }

  let(:service) do
    params = { ref: ref_name,
               before: '00000000',
               after: project.commit.id,
               commits: [{ message: 'some commit' }] }

    described_class.new(project, user, params)
  end

  before_all do
    create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan)
    project.add_developer(user)
  end

  before do
    stub_ci_pipeline_to_return_yaml_file
  end

  describe 'CI/CD Quotas / Limits' do
    context 'when there are not limits enabled' do
      it 'enqueues a new pipeline', :aggregate_failures do
        response, pipeline = create_pipeline!

        expect(response).to be_success
        expect(pipeline).to be_created_successfully
      end
    end

    context 'when pipeline size limit is exceeded' do
      before do
        plan_limits.update_column(:ci_pipeline_size, 2)
      end

      it 'drops pipeline without creating jobs', :aggregate_failures do
        response, pipeline = create_pipeline!

        expect(response).to be_error
        expect(pipeline).to be_persisted
        expect(pipeline).to be_failed
        expect(pipeline.statuses).to be_empty
        expect(pipeline.size_limit_exceeded?).to be true
      end
    end
  end

  describe 'cross-project pipeline triggers' do
    before do
      stub_ci_pipeline_yaml_file <<~YAML
        test:
          script: rspec

        deploy:
          variables:
            CROSS: downstream
          stage: deploy
          trigger: my/project
      YAML
    end

    it 'creates bridge jobs correctly', :aggregate_failures do
      response, pipeline = create_pipeline!

      test = pipeline.statuses.find_by(name: 'test')
      bridge = pipeline.statuses.find_by(name: 'deploy')

      expect(response).to be_success
      expect(pipeline).to be_persisted
      expect(test).to be_a Ci::Build
      expect(bridge).to be_a Ci::Bridge
      expect(bridge.ci_stage.name).to eq 'deploy'
      expect(pipeline.statuses).to match_array [test, bridge]
      expect(bridge.options).to eq(trigger: { project: 'my/project' })
      expect(bridge.yaml_variables)
        .to include(key: 'CROSS', value: 'downstream')
    end

    context 'when configured with rules' do
      before do
        stub_ci_pipeline_yaml_file(config)
      end

      let(:downstream_project) { create(:project, :repository) }

      let(:config) do
        <<-YAML
          hello:
            script: echo world

          bridge-job:
            rules:
              - if: $CI_COMMIT_REF_NAME == "master"
            trigger:
              project: #{downstream_project.full_path}
              branch: master
        YAML
      end

      context 'that include the bridge job' do
        it 'persists the bridge job' do
          _, pipeline = create_pipeline!

          expect(pipeline.processables.pluck(:name)).to contain_exactly('hello', 'bridge-job')
        end
      end

      context 'that exclude the bridge job' do
        let(:ref_name) { 'refs/heads/wip' }

        it 'does not include the bridge job' do
          _, pipeline = create_pipeline!

          expect(pipeline.processables.pluck(:name)).to eq(%w[hello])
        end
      end
    end
  end

  describe 'job with secrets' do
    before do
      stub_ci_pipeline_yaml_file <<~YAML
        deploy:
          script:
            - echo
          secrets:
            DATABASE_PASSWORD:
              vault: production/db/password
              token: $ID_TOKEN
      YAML
    end

    it 'persists secrets as job metadata', :aggregate_failures do
      response, pipeline = create_pipeline!

      expect(response).to be_success
      expect(pipeline).to be_persisted

      build = Ci::Build.find(pipeline.builds.first.id)

      expect(build.secrets).to eq({
        'DATABASE_PASSWORD' => {
          'vault' => {
            'engine' => { 'name' => 'kv-v2', 'path' => 'kv-v2' },
            'path' => 'production/db',
            'field' => 'password'
          },
          'token' => '$ID_TOKEN'
        }
      })
    end

    describe 'secrets management usage tracking' do
      before do
        allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).and_call_original
      end

      context 'when the secrets management feature is available' do
        before do
          stub_licensed_features(ci_secrets_management: true)
        end

        it 'tracks the RedisHLL event for the provider with the user id' do
          expect(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
            .with('i_ci_secrets_management_vault_build_created', values: user.id)

          create_pipeline!
        end

        it 'tracks the Snowplow event for the provider with the RedisHLL context' do
          _, pipeline = create_pipeline!
          build = pipeline.builds.order(:id).first

          expect_snowplow_event(
            category: 'Ci::Build',
            action: 'create_secrets_vault',
            namespace: build.namespace,
            user: user,
            label: 'redis_hll_counters.ci_secrets_management.i_ci_secrets_management_vault_build_created_monthly',
            ultimate_namespace_id: build.namespace.root_ancestor.id,
            context: [::Gitlab::Tracking::ServicePingContext.new(
              data_source: :redis_hll,
              event: 'i_ci_secrets_management_vault_build_created'
            ).to_context.to_json]
          )
        end

        it 'does not track unused providers' do
          unused_providers = Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS - [:vault]
          unused_providers.each do |provider|
            expect(::Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event)
              .with("i_ci_secrets_management_#{provider}_build_created", values: user.id)
          end

          create_pipeline!

          unused_providers.each do |provider|
            expect_no_snowplow_event(category: 'Ci::Build', action: "create_secrets_#{provider}")
          end
        end

        context 'when the pipeline has no secrets' do
          before do
            stub_ci_pipeline_yaml_file <<~YAML
              deploy:
                script:
                  - echo
            YAML
          end

          it 'does not track usage' do
            expect(::Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event)
              .with('i_ci_secrets_management_vault_build_created', values: user.id)

            create_pipeline!

            expect_no_snowplow_event(category: 'Ci::Build', action: 'create_secrets_vault')
          end
        end
      end

      context 'when the secrets management feature is not available' do
        before do
          stub_licensed_features(ci_secrets_management: false)
        end

        it 'does not track usage' do
          expect(::Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event)
            .with('i_ci_secrets_management_vault_build_created', values: user.id)

          create_pipeline!

          expect_no_snowplow_event(category: 'Ci::Build', action: 'create_secrets_vault')
        end
      end
    end
  end

  context 'with partition_id param' do
    let_it_be_with_reload(:user) { project.first_owner }

    let(:ref_name) { 'refs/heads/master' }
    let(:pipeline_policy_context) { nil }

    subject(:execute_service) do
      described_class.new(
        project,
        user,
        source: :push,
        before: '00000000',
        after: project.commit.id,
        ref: ref_name,
        partition_id: ci_testing_partition_id
      ).execute(
        :push,
        save_on_errors: true,
        pipeline_policy_context: pipeline_policy_context
      )
    end

    it 'raises error' do
      expect { execute_service }
        .to raise_error(ArgumentError, "Param `partition_id` is only allowed with `pipeline_policy_context`")
    end

    context 'when used with `pipeline_policy_context` param' do
      let(:pipeline_policy_context) do
        Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project)
      end

      it 'does not raise an error' do
        expect(execute_service)
          .to be_success
      end
    end
  end

  context 'when pipeline is not created' do
    it 'does not invoke an async onboarding progress update' do
      stub_ci_pipeline_yaml_file(nil)
      expect(Onboarding::ProgressService).not_to receive(:async)

      create_pipeline!
    end
  end

  context 'when pipeline is created' do
    it 'invokes an async onboarding progress update' do
      expect(Onboarding::ProgressService).to receive(:async).with(project.namespace_id, 'pipeline_created')

      create_pipeline!
    end
  end

  def create_pipeline!
    response = service.execute(:push)

    [response, response.payload]
  end
end
