# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::YamlProcessor, feature_category: :pipeline_composition do
  let(:opts) { {} }

  subject(:result) { described_class.new(YAML.dump(config), opts).execute }

  describe 'Bridge Needs' do
    let(:config) do
      {
        build: { stage: 'build', script: 'test' },
        bridge: { stage: 'test', needs: needs }
      }
    end

    context 'when needs upstream pipeline' do
      let(:needs) { { pipeline: 'some/project' } }

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(2)
        expect(result.builds[0]).to eq(
          stage: "build",
          stage_idx: 1,
          name: "build",
          only: { refs: %w[branches tags] },
          options: {
            script: ["test"]
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
        expect(result.builds[1]).to eq(
          stage: "test",
          stage_idx: 2,
          name: "bridge",
          only: { refs: %w[branches tags] },
          options: {
            bridge_needs: { pipeline: 'some/project' }
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
      end
    end

    context 'when needs both job and pipeline' do
      let(:needs) { ['build', { pipeline: 'some/project' }] }

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(2)
        expect(result.builds[0]).to eq(
          stage: "build",
          stage_idx: 1,
          name: "build",
          only: { refs: %w[branches tags] },
          options: {
            script: ["test"]
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
        expect(result.builds[1]).to eq(
          stage: "test",
          stage_idx: 2,
          name: "bridge",
          only: { refs: %w[branches tags] },
          options: {
            bridge_needs: { pipeline: 'some/project' }
          },
          needs_attributes: [
            { name: "build", artifacts: true, optional: false }
          ],
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
      end
    end

    context 'when needs cross projects artifacts' do
      let(:config) do
        {
          build: { stage: 'build', script: 'test' },
          test1: { stage: 'test', script: 'test', needs: needs },
          test2: { stage: 'test', script: 'test' }
        }
      end

      let(:needs) do
        [
          { job: 'build' },
          {
            project: 'some/project',
            ref: 'some/ref',
            job: 'build2',
            artifacts: true
          },
          {
            project: 'some/other/project',
            ref: 'some/ref',
            job: 'build3',
            artifacts: false
          },
          {
            project: 'project',
            ref: 'master',
            job: 'build4'
          }
        ]
      end

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(3)

        expect(result.builds[1]).to eq(
          stage: 'test',
          stage_idx: 2,
          name: 'test1',
          options: {
            script: ['test'],
            cross_dependencies: [
              {
                artifacts: true,
                job: 'build2',
                project: 'some/project',
                ref: 'some/ref'
              },
              {
                artifacts: false,
                job: 'build3',
                project: 'some/other/project',
                ref: 'some/ref'
              },
              {
                artifacts: true,
                job: 'build4',
                project: 'project',
                ref: 'master'
              }
            ]
          },
          needs_attributes: [
            { name: 'build', artifacts: true, optional: false }
          ],
          only: { refs: %w[branches tags] },
          when: 'on_success',
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :dag
        )
      end
    end

    context 'when needs cross projects artifacts and pipelines' do
      let(:needs) do
        [
          {
            project: 'some/project',
            ref: 'some/ref',
            job: 'build',
            artifacts: true
          },
          {
            pipeline: 'other/project'
          }
        ]
      end

      it 'returns errors' do
        expect(result.errors).to include(
          'jobs:bridge config should contain either a trigger or a needs:pipeline')
      end
    end

    context 'with invalid needs cross projects artifacts' do
      let(:config) do
        {
          build: { stage: 'build', script: 'test' },
          test: {
            stage: 'test',
            script: 'test',
            needs: {
              project: 'some/project',
              ref: 1,
              job: 'build',
              artifacts: true
            }
          }
        }
      end

      it 'returns errors' do
        expect(result.errors).to contain_exactly(
          'jobs:test:needs:need ref should be a string')
      end
    end

    describe 'with cross pipeline needs' do
      context 'when job is not present' do
        let(:config) do
          {
            rspec: {
              stage: 'test',
              script: 'rspec',
              needs: [
                { pipeline: '$UPSTREAM_PIPELINE_ID' }
              ]
            }
          }
        end

        it 'returns an error' do
          expect(result).not_to be_valid
          # This currently shows a confusing error message because a conflict of syntax
          # with upstream pipeline status mirroring: https://gitlab.com/gitlab-org/gitlab/-/issues/280853
          expect(result.errors).to include(/:needs config uses invalid types: bridge/)
        end
      end
    end

    describe 'with cross project and cross pipeline needs' do
      let(:config) do
        {
          rspec: {
            stage: 'test',
            script: 'rspec',
            needs: [
              { pipeline: '$UPSTREAM_PIPELINE_ID', job: 'test' },
              { project: 'org/the-project', ref: 'master', job: 'build', artifacts: true }
            ]
          }
        }
      end

      it 'returns a valid specification' do
        expect(result).to be_valid

        rspec = result.builds.last
        expect(rspec.dig(:options, :cross_dependencies)).to eq(
          [
            { pipeline: '$UPSTREAM_PIPELINE_ID', job: 'test', artifacts: true },
            { project: 'org/the-project', ref: 'master', job: 'build', artifacts: true }
          ])
      end
    end

    describe 'dast configuration' do
      let(:config) do
        {
          build: {
            stage: 'build',
            dast_configuration: { site_profile: 'Site profile', scanner_profile: 'Scanner profile' },
            script: 'test'
          }
        }
      end

      it 'creates a job with a valid specification' do
        expect(result.builds[0][:options]).to include(
          dast_configuration: { site_profile: 'Site profile', scanner_profile: 'Scanner profile' }
        )
      end
    end
  end

  describe 'secrets' do
    context 'on hashicorp vault' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            vault: 'production/db/password'
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            vault: {
              engine: { name: 'kv-v2', path: 'kv-v2' },
              path: 'production/db',
              field: 'password'
            }
          }
        })
      end
    end

    context 'on aws_secrets_manager' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            aws_secrets_manager: 'production/db/password#password'
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            aws_secrets_manager: {
              secret_id: 'production/db/password',
              field: 'password'
            }
          }
        })
      end
    end

    context 'on gitlab_secrets_manager' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            gitlab_secrets_manager: {
              name: 'password'
            }
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            gitlab_secrets_manager: {
              name: 'password'
            }
          }
        })
      end
    end

    context 'on azure key vault' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            azure_key_vault: {
              name: 'key',
              version: 'version'
            }
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            azure_key_vault: {
              name: 'key',
              version: 'version'
            }
          }
        })
      end
    end
  end

  describe 'identity', feature_category: :secrets_management do
    let_it_be_with_refind(:project) { create(:project, :small_repo) }
    let_it_be_with_refind(:integration) do
      create(:google_cloud_platform_workload_identity_federation_integration, project: project)
    end

    let(:google_cloud_support) { true }
    let(:opts) { { project: project } }
    let(:config) do
      {
        build: {
          stage: 'build', script: 'test',
          identity: 'google_cloud'
        }
      }
    end

    before do
      stub_saas_features(google_cloud_support: google_cloud_support)
    end

    it 'includes identity-related values', :aggregate_failures do
      identity = result.builds.first.dig(:options, :identity)

      expect(identity).to eq('google_cloud')
      expect(result.errors).to be_empty
    end

    context 'when SaaS feature is not available' do
      let(:google_cloud_support) { false }

      it 'returns error' do
        expect(result.errors).to include(a_string_including(
          s_("GoogleCloud|The google_cloud_support feature is not available")))
      end
    end

    context 'when project integration does not exist' do
      before do
        integration.destroy!
      end

      it 'returns error' do
        expect(result.errors).to include(a_string_including(
          s_('GoogleCloud|The Google Cloud Identity and Access Management integration is not ' \
             'configured for this project')))
      end
    end

    context 'when project integration exists and is not enabled' do
      before do
        integration.update_column(:active, false)
      end

      it 'returns error' do
        expect(result.errors).to include(a_string_including(
          s_('GoogleCloud|The Google Cloud Identity and Access Management integration is not enabled ' \
             'for this project')))
      end
    end
  end

  describe 'stages' do
    subject(:stages) { result.stages }

    let(:config) do
      {
        rspec: {
          script: 'rspec'
        }
      }
    end

    it { is_expected.to eq(%w[.pre build test deploy .post]) }

    context 'with pipeline_policy_context' do
      include_context 'with pipeline policy context'

      let(:opts) { { pipeline_policy_context: pipeline_policy_context } }

      it { is_expected.to eq(%w[.pre build test deploy .post]) }

      shared_examples_for 'stages including policy reserved stages' do
        it { is_expected.to eq(%w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post]) }
      end

      context 'when creating_policy_pipeline? is true' do
        let(:creating_policy_pipeline) { true }

        it_behaves_like 'stages including policy reserved stages'
      end

      context 'with execution_policy_pipelines' do
        let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

        it_behaves_like 'stages including policy reserved stages'
      end
    end
  end

  describe '#validate_job_stage!' do
    include_context 'with pipeline policy context'

    shared_examples_for 'reserved stage not allowed' do |stage|
      it 'does not allow usage of reserved stages and returns error' do
        expect(result.errors).to include(
          a_string_including("build job: chosen stage `#{stage}` is reserved for Pipeline Execution Policies")
        )
      end
    end

    %w[.pipeline-policy-pre .pipeline-policy-post].each do |stage|
      context "when stage is #{stage}" do
        let(:config) do
          {
            stages: [stage, 'test'],
            build: { stage: stage, script: 'build' },
            test: { stage: 'test', script: 'test' }
          }
        end

        context 'without pipeline_policy_context' do
          it_behaves_like 'reserved stage not allowed', stage
        end

        context 'with pipeline_policy_context' do
          let(:opts) { { pipeline_policy_context: pipeline_policy_context } }

          it_behaves_like 'reserved stage not allowed', stage

          context 'when creating_policy_pipeline? is true' do
            let(:creating_policy_pipeline) { true }

            it 'is valid' do
              expect(result.errors).to be_empty
            end
          end
        end
      end
    end
  end

  describe '#builds' do
    subject(:builds) { result.builds }

    describe 'policy option' do
      include_context 'with pipeline policy context'

      let(:current_policy) do
        build(:pipeline_execution_policy_config, policy_sha: 'my_policy_sha',
          policy: build(:pipeline_execution_policy, :variables_override_disallowed, name: 'My policy'))
      end

      let(:opts) { { pipeline_policy_context: pipeline_policy_context } }
      let(:config) do
        { rspec: { script: 'rspec' } }
      end

      it 'does not set `policy` in :options' do
        expect(builds).to match([a_hash_including(options: { script: ['rspec'] })])
      end

      context 'when creating_policy_pipeline? is true' do
        let(:creating_policy_pipeline) { true }

        it 'marks the build as `policy` in :options' do
          expect(builds).to match([a_hash_including(options: {
            script: ['rspec'],
            policy: {
              pipeline_execution_policy_job: true,
              name: 'My policy',
              project_id: policy_project_id,
              sha: 'my_policy_sha',
              variables_override: { allowed: false }
            }
          })])
        end
      end
    end
  end
end
