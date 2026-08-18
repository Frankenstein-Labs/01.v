# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::YamlProcessor::Result, feature_category: :pipeline_composition do
  include StubRequests

  let_it_be(:user) { create(:user) }

  let(:ci_config) { Gitlab::Ci::Config.new(config_content, user: user) }
  let(:result) { described_class.new(ci_config: ci_config, warnings: ci_config&.warnings) }

  subject(:build) { result.builds.first }

  describe '#builds' do
    context 'when a job has identity', feature_category: :secrets_management do
      let(:config_content) do
        YAML.dump(
          test: { stage: 'test', script: 'echo', identity: 'google_cloud' }
        )
      end

      before do
        stub_saas_features(google_cloud_support: true)
      end

      it 'includes :identity in :options' do
        expect(build.dig(:options, :identity)).to eq('google_cloud')
      end
    end

    describe 'policy' do
      describe 'name' do
        include_context 'with pipeline policy context'

        let(:creating_policy_pipeline) { true }
        let(:pipeline) { FactoryBot.build(:ci_empty_pipeline, ref: 'master') }
        let(:ci_config) do
          Gitlab::Ci::Config.new(config_content, user: user, pipeline_policy_context: pipeline_policy_context,
            pipeline: pipeline)
        end

        let(:config_content) do
          YAML.dump(
            test: { stage: 'test', script: 'echo' }
          )
        end

        it 'saves the policy data in :options' do
          expect(build.dig(:options, :policy))
            .to eq(pipeline_execution_policy_job: true, name: 'Policy', sha: policy_config_sha,
              project_id: policy_project_id)
        end

        context 'when creating_policy_pipeline? is false' do
          let(:creating_policy_pipeline) { false }

          it 'does not mark the build as `policy` via :options' do
            expect(build.dig(:options, :policy)).to be_nil
          end

          context 'when job was injected by scan execution policies' do
            before do
              metadata_key = ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY

              pipeline_policy_context.scan_execution_context('refs/heads/master')
                .collect_injected_job_names_with_metadata(test: {
                  metadata_key => { name: 'My policy', sha: 'SEP SHA', project_id: 123 }
                })
            end

            it 'saves the policy data in :options' do
              expect(build.dig(:options, :policy)).to eq(name: 'My policy', sha: 'SEP SHA', project_id: 123)
            end
          end
        end
      end

      describe 'variables_override' do
        include_context 'with pipeline policy context'

        let(:creating_policy_pipeline) { true }
        let(:ci_config) do
          Gitlab::Ci::Config.new(config_content, user: user, pipeline_policy_context: pipeline_policy_context)
        end

        let(:config_content) do
          YAML.dump(
            test: { stage: 'test', script: 'echo' }
          )
        end

        context 'when policy does not have variables_override' do
          let(:current_policy) { FactoryBot.build(:pipeline_execution_policy_config) }

          it 'does not set `variables_override` option' do
            expect(build.dig(:options, :policy, :variables_override)).to be_nil
          end
        end

        context 'when policy has variables_override' do
          let(:current_policy) { FactoryBot.build(:pipeline_execution_policy_config, :variables_override_disallowed) }

          it 'sets `variables_override` option' do
            expect(build.dig(:options, :policy, :variables_override)).to eq({ allowed: false })
          end
        end

        context 'when creating_policy_pipeline? is false' do
          let(:creating_policy_pipeline) { false }

          it 'does not set `variables_override` option' do
            expect(build.dig(:options, :policy, :variables_override)).to be_nil
          end
        end
      end
    end
  end
end
