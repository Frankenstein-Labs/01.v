# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::ProjectConfig, feature_category: :pipeline_composition do
  let_it_be_with_reload(:project) { create(:project, :empty_repo) }
  let(:sha) { '123456' }
  let(:content) { nil }
  let(:source) { :push }
  let(:bridge) { nil }
  let(:triggered_for_branch) { true }
  let(:ref) { 'master' }
  let(:source_branch) { 'master' }
  let(:has_execution_policy_pipelines) { false }
  let(:has_overriding_execution_policy_pipelines) { false }
  let(:creating_policy_pipeline) { false }
  let(:scan_profile_context) { nil }
  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project)
  end

  before do
    allow(pipeline_policy_context.pipeline_execution_context).to(
      receive_messages(
        has_overriding_execution_policy_pipelines?: has_overriding_execution_policy_pipelines,
        has_execution_policy_pipelines?: has_execution_policy_pipelines,
        creating_policy_pipeline?: creating_policy_pipeline
      )
    )
  end

  subject(:config) do
    described_class.new(
      project: project,
      sha: sha,
      custom_content: content,
      pipeline_source: source,
      pipeline_source_bridge: bridge,
      triggered_for_branch: triggered_for_branch,
      ref: ref,
      source_branch: source_branch,
      pipeline_policy_context: pipeline_policy_context,
      scan_profile_context: scan_profile_context
    )
  end

  context 'when config is Compliance' do
    let(:content_result) do
      <<~CICONFIG
        ---
        include:
        - project: compliance/hippa
          file: ".compliance-gitlab-ci.yml"
      CICONFIG
    end

    shared_examples 'does not include compliance pipeline configuration content' do
      it do
        expect(config.source).not_to eq(:compliance_source)
        expect(config.content).not_to eq(content_result)
      end
    end

    context 'when project has compliance label defined' do
      let_it_be(:compliance_group) { create(:group, :private, name: "compliance") }
      let_it_be(:compliance_project) { create(:project, namespace: compliance_group, name: "hippa") }

      context 'when feature is available' do
        before do
          stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
        end

        context 'when compliance pipeline configuration is defined' do
          let(:framework) do
            create(
              :compliance_framework,
              namespace: compliance_group,
              pipeline_configuration_full_path: ".compliance-gitlab-ci.yml@compliance/hippa"
            )
          end

          let!(:framework_project_setting) do
            create(:compliance_framework_project_setting, project: project,
              compliance_management_framework: framework)
          end

          it 'includes compliance pipeline configuration content' do
            expect(config.source).to eq(:compliance_source)
            expect(config.content).to eq(content_result)
          end

          context 'when pipeline is downstream of a bridge' do
            let(:bridge) { create(:ci_bridge) }

            it 'does include compliance pipeline configuration' do
              expect(config.source).to eq(:compliance_source)
              expect(config.content).to eq(content_result)
            end

            context 'when pipeline source is parent pipeline' do
              let(:source) { :parent_pipeline }

              it_behaves_like 'does not include compliance pipeline configuration content'
            end

            context 'with overriding execution policies' do
              let(:has_overriding_execution_policy_pipelines) { true }

              it_behaves_like 'does not include compliance pipeline configuration content'
            end
          end

          context 'when the source is on-demand dast scan' do
            let(:source) { :ondemand_dast_scan }
            let(:content) { "---\ninclude:\n- template: DAST-On-Demand-Scan.gitlab-ci.yml\n" }
            let(:content_result) do
              <<~CICONFIG
                ---
                include:
                - template: DAST-On-Demand-Scan.gitlab-ci.yml
              CICONFIG
            end

            it 'does not include compliance pipeline configuration' do
              expect(config.source).to eq(:parameter_source)
              expect(config.content).to eq(content_result)
            end
          end
        end

        context 'when compliance pipeline configuration is not defined' do
          let(:framework) { create(:compliance_framework, namespace: compliance_group) }
          let!(:framework_project_setting) do
            create(:compliance_framework_project_setting, project: project,
              compliance_management_framework: framework)
          end

          it_behaves_like 'does not include compliance pipeline configuration content'
        end

        context 'when compliance pipeline configuration is empty' do
          let(:framework) do
            create(:compliance_framework, namespace: compliance_group, pipeline_configuration_full_path: '')
          end

          let!(:framework_project_setting) do
            create(:compliance_framework_project_setting, project: project,
              compliance_management_framework: framework)
          end

          it_behaves_like 'does not include compliance pipeline configuration content'
        end
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(evaluate_group_level_compliance_pipeline: false)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end
    end

    context 'when project does not have compliance label defined' do
      context 'when feature is available' do
        before do
          stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end
    end
  end

  context 'when config is SecurityPolicyDefault' do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let!(:security_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let(:policy) { build(:scan_execution_policy, enabled: true, rules: [rule]) }
    let(:branches) { %w[master production] }

    before do
      allow(project).to receive(:all_security_orchestration_policy_configurations)
                          .and_return([security_policy_configuration])

      allow(security_policy_configuration).to receive(:active_scan_execution_policies).and_return([policy])
    end

    shared_examples_for 'with pipeline execution policies enforced' do
      let(:has_execution_policy_pipelines) { true }
      let(:expected_content) { YAML.dump(Gitlab::Ci::ProjectConfig::SecurityPolicyDefault::DUMMY_CONTENT) }

      it 'includes dummy job to force the pipeline creation' do
        expect(config.source).to eq(:pipeline_execution_policy_forced)
        expect(config.content).to eq(expected_content)
      end

      context 'with overriding execution policies' do
        let(:has_overriding_execution_policy_pipelines) { true }

        it 'includes dummy job to force the pipeline creation' do
          expect(config.source).to eq(:pipeline_execution_policy_forced)
          expect(config.content).to eq(expected_content)
        end
      end
    end

    shared_examples_for 'includes security policies default pipeline configuration content' do
      it 'includes security policies default pipeline configuration content' do
        expect(config.source).to eq(:security_policies_default_source)
        expect(config.content).to eq(security_policy_default_content)
      end
    end

    context 'when policies should be enforced' do
      context 'when security_orchestration_policies feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        let(:security_policy_default_content) { YAML.dump(nil) }

        context 'when auto devops is not enabled' do
          before do
            stub_application_setting(auto_devops_enabled: false)
          end

          context 'when active policies includes a rule with pipeline type' do
            let(:rule) { { type: 'pipeline', branches: branches } }

            context 'when policy applies to the pipeline\'s branch' do
              context 'when pipeline execution policies are enforced' do
                let(:has_execution_policy_pipelines) { true }

                it_behaves_like 'includes security policies default pipeline configuration content'

                context 'when branch_type is target_default' do
                  let(:rule) { { type: 'pipeline', branch_type: 'target_default' } }

                  context 'with open merge request created targeting default branch' do
                    let(:source_branch) { 'dev' }

                    before do
                      create(:merge_request, :opened, source_project: project, source_branch: source_branch,
                        target_project: project, target_branch: project.default_branch)
                    end

                    it_behaves_like 'includes security policies default pipeline configuration content'
                  end
                end
              end

              context 'when pipeline execution policies are not enforced' do
                let(:has_execution_policy_pipelines) { false }

                it_behaves_like 'includes security policies default pipeline configuration content'
              end
            end

            context 'when triggered for merge request pipelines' do
              let(:source) { :merge_request_event }

              context 'when ref and source branch are the same' do
                it_behaves_like 'includes security policies default pipeline configuration content'
              end

              context 'when ref and source branch are different' do
                let(:ref) { 'refs/merge-requests/1/head' }

                it_behaves_like 'includes security policies default pipeline configuration content'
              end
            end

            context 'when source is passed as string' do
              %w[push merge_request_event].each do |source|
                context "when source is #{source}" do
                  let(:source) { source }

                  it_behaves_like 'includes security policies default pipeline configuration content'
                end
              end
            end

            context 'when policy has pipeline_sources restrictions' do
              let(:rule) do
                {
                  type: 'pipeline',
                  branches: branches,
                  pipeline_sources: { including: policy_pipeline_sources }
                }
              end

              context 'when pipeline_sources includes the current source' do
                let(:policy_pipeline_sources) { %w[push] }
                let(:source) { :push }

                it_behaves_like 'includes security policies default pipeline configuration content'
              end

              context 'when pipeline_sources does not include the current source' do
                let(:policy_pipeline_sources) { %w[web] }
                let(:source) { :push }

                it 'does not include security policies default pipeline configuration content' do
                  expect(config.source).to be_nil
                end
              end

              context 'when pipeline_sources includes multiple sources' do
                let(:policy_pipeline_sources) { %w[push web merge_request_event] }

                context 'when source matches one of the allowed sources' do
                  let(:source) { :merge_request_event }

                  it_behaves_like 'includes security policies default pipeline configuration content'
                end

                context 'when source does not match any allowed source' do
                  let(:source) { :schedule }

                  it 'does not include security policies default pipeline configuration content' do
                    expect(config.source).to be_nil
                  end
                end
              end

              context 'when policy has multiple rules with different pipeline_sources' do
                let(:policy) do
                  build(:scan_execution_policy, enabled: true, rules: [
                    { type: 'pipeline', branches: branches, pipeline_sources: { including: %w[web] } },
                    { type: 'pipeline', branches: branches, pipeline_sources: { including: %w[push] } }
                  ])
                end

                context 'when source matches one of the rules' do
                  let(:source) { :push }

                  it_behaves_like 'includes security policies default pipeline configuration content'
                end

                context 'when source does not match any rule' do
                  let(:source) { :schedule }

                  it 'does not include security policies default pipeline configuration content' do
                    expect(config.source).to be_nil
                  end
                end
              end

              context 'when source is passed as string' do
                let(:policy_pipeline_sources) { %w[push] }
                let(:source) { 'push' }

                it_behaves_like 'includes security policies default pipeline configuration content'
              end
            end

            describe '#policy_applicable_for_pipeline_source?' do
              let(:rule) do
                {
                  type: 'pipeline',
                  branches: branches,
                  pipeline_sources: { including: %w[push] }
                }
              end

              let(:fallback_config) do
                Gitlab::Ci::ProjectConfig::SecurityPolicyDefault.new(
                  project: project,
                  pipeline_source: pipeline_source_value,
                  triggered_for_branch: true,
                  source_branch: source_branch,
                  pipeline_policy_context: pipeline_policy_context
                )
              end

              context 'when pipeline_source is blank' do
                let(:pipeline_source_value) { nil }

                it 'returns true for the policy' do
                  result = fallback_config.send(:policy_applicable_for_pipeline_source?, policy)
                  expect(result).to be(true)
                end
              end

              context 'when pipeline_source is present' do
                let(:pipeline_source_value) { :push }

                it 'checks against policy rules' do
                  result = fallback_config.send(:policy_applicable_for_pipeline_source?, policy)
                  expect(result).to be(true)
                end
              end
            end
          end
        end
      end
    end

    context 'when policies should not be enforced' do
      let(:rule) { { type: 'pipeline', branches: branches } }
      let(:licensed_security_orchestration_policies) { true }

      before do
        stub_licensed_features(security_orchestration_policies: licensed_security_orchestration_policies)
      end

      shared_examples 'does not include security policies default pipeline configuration content' do
        context 'when auto devops is not enabled' do
          before do
            stub_application_setting(auto_devops_enabled: false)
          end

          it 'does not include security policies default pipeline configuration content' do
            expect(config.source).to be_nil
          end
        end
      end

      context 'when security_orchestration_policies feature is not available' do
        let(:licensed_security_orchestration_policies) { false }

        it_behaves_like 'does not include security policies default pipeline configuration content'
      end

      context 'when is not triggered for branch' do
        let(:triggered_for_branch) { false }

        it_behaves_like 'does not include security policies default pipeline configuration content'
      end

      context 'when auto devops is enabled' do
        it 'does not include security policies default pipeline configuration content' do
          expect(config.source).to eq(:auto_devops_source)
        end

        context 'with overriding policies' do
          let(:has_execution_policy_pipelines) { true }
          let(:has_overriding_execution_policy_pipelines) { true }

          it 'includes security policies default pipeline configuration content' do
            expect(config.source).to eq(:security_policies_default_source)
          end
        end
      end

      context 'when auto devops is not enabled' do
        before do
          stub_application_setting(auto_devops_enabled: false)
        end

        context 'when active policies does not include a rule with pipeline type' do
          let(:rule) { { type: 'schedule', branches: branches, cadence: '*/20 * * * *' } }

          it 'does not include security policies default pipeline configuration content' do
            expect(config.source).to be_nil
          end

          it_behaves_like 'with pipeline execution policies enforced'

          context 'when triggered for merge request pipelines' do
            let(:source) { :merge_request_event }

            it_behaves_like 'does not include security policies default pipeline configuration content'
          end
        end

        context 'when policy does not apply to the branch' do
          let(:rule) { { type: 'pipeline', branches: ['main'] } }

          it 'does not include security policies default pipeline configuration content' do
            expect(config.source).to be_nil
          end

          it_behaves_like 'with pipeline execution policies enforced'

          context 'when triggered for merge request pipelines' do
            let(:source) { :merge_request_event }

            context 'when ref and source branch are the same' do
              it_behaves_like 'does not include security policies default pipeline configuration content'
            end

            context 'when ref and source branch are different' do
              let(:ref) { 'refs/merge-requests/1/head' }

              it_behaves_like 'does not include security policies default pipeline configuration content'
            end
          end
        end

        context 'when the policy should not be enforced to the pipeline source' do
          Enums::Ci::Pipeline.dangling_sources.except(:security_orchestration_policy).each_key do |source|
            context "when pipeline source is #{source}" do
              let(:source) { source }

              it_behaves_like 'does not include security policies default pipeline configuration content'
            end
          end

          context 'when pipeline source is nil' do
            let(:source) { nil }

            it_behaves_like 'does not include security policies default pipeline configuration content'
          end
        end
      end
    end
  end

  shared_examples_for 'config source with overriding execution policies' do |source|
    it 'uses the defined source' do
      expect(config.source).to eq(source)
    end

    context 'with overriding policies' do
      let(:has_execution_policy_pipelines) { true }
      let(:has_overriding_execution_policy_pipelines) { true }

      it 'uses the pipeline_execution_policy_forced source' do
        expect(config.source).to eq(:pipeline_execution_policy_forced)
      end

      context 'when creating policy pipeline' do
        let(:creating_policy_pipeline) { true }

        it 'uses the defined source' do
          expect(config.source).to eq(source)
        end
      end
    end
  end

  context 'when config is Bridge' do
    let(:bridge) { build_stubbed(:ci_bridge) }

    before do
      allow(bridge).to receive(:yaml_for_downstream).and_return('the-yaml')
    end

    it_behaves_like 'config source with overriding execution policies', :bridge_source
  end

  context 'when config is Parameter' do
    let(:content) do
      <<~CICONFIG
        ---
        stages:
        - dast
      CICONFIG
    end

    it_behaves_like 'config source with overriding execution policies', :parameter_source
  end

  context 'when config is Auto-Devops' do
    before do
      allow(project).to receive(:auto_devops_enabled?).and_return(true)
    end

    it_behaves_like 'config source with overriding execution policies', :auto_devops_source
  end

  context 'when config is SecurityScanProfile' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :empty_repo, group: group) }
    let_it_be(:scan_profile) { create(:security_scan_profile, :sast, namespace: group, projects: [project]) }

    before do
      stub_licensed_features(security_scan_profiles: true)
      allow(project).to receive(:auto_devops_enabled?).and_return(false)
    end

    shared_examples 'does not include security scan profile pipeline configuration' do
      it 'does not include security scan profile pipeline configuration' do
        expect(config.source).not_to eq(:security_scan_profiles_source)
      end
    end

    shared_examples 'includes security scan profile pipeline configuration' do
      it 'includes security scan profile pipeline configuration' do
        expect(config.source).to eq(:security_scan_profiles_source)
        expect(config.content).to eq(YAML.dump(nil))
      end
    end

    shared_examples 'checks `security_scan_profiles` licensed feature' do
      before do
        stub_licensed_features(security_scan_profiles: false)
      end

      it_behaves_like 'does not include security scan profile pipeline configuration'
    end

    context 'when scan_profile_context is not provided' do
      it_behaves_like 'does not include security scan profile pipeline configuration'
    end

    context 'when scan_profile_context is provided' do
      let(:scan_profile_context) do
        Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext.new(
          project: project,
          ref: ref,
          pipeline_source: source
        )
      end

      context 'when there are no applicable profile triggers' do
        it_behaves_like 'does not include security scan profile pipeline configuration'
      end

      context 'when trigger is for default branch pipeline' do
        let_it_be(:trigger) do
          create(:security_scan_profile_trigger, trigger_type: :default_branch_pipeline, scan_profile: scan_profile)
        end

        let(:ref) { project.default_branch_or_main }

        it_behaves_like 'checks `security_scan_profiles` licensed feature'

        it_behaves_like 'includes security scan profile pipeline configuration'

        context 'when ref is not the default branch' do
          let(:ref) { 'feature-branch' }

          it_behaves_like 'does not include security scan profile pipeline configuration'
        end
      end

      context 'when trigger is for merge request pipeline' do
        let_it_be(:trigger) do
          create(:security_scan_profile_trigger, trigger_type: :merge_request_pipeline, scan_profile: scan_profile)
        end

        let(:source) { :merge_request_event }

        it_behaves_like 'checks `security_scan_profiles` licensed feature'

        it_behaves_like 'includes security scan profile pipeline configuration'

        context 'when source is not merge_request_event' do
          let(:source) { :web }

          it_behaves_like 'does not include security scan profile pipeline configuration'
        end
      end
    end
  end
end
