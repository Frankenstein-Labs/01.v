# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::SecurityOrchestrationPolicies::Processor, feature_category: :security_policy_management do
  subject(:perform_service) { described_class.new(config, ci_context, ref, pipeline_policy_context).perform }

  let(:config) { { image: 'image:1.0.0' } }
  let(:ci_context) { Gitlab::Ci::Config::External::Context.new(project: project) }
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
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      source: source,
      origin_ref: project.default_branch_or_main)
  end

  let(:ref) { 'refs/heads/master' }
  let(:source) { 'pipeline' }
  let(:scan_policy_stage) { 'test' }
  let(:policies) { {} }

  let_it_be(:namespace) { create(:group) }
  let_it_be(:policy_files) { { Security::OrchestrationPolicyConfiguration::POLICY_PATH => '' } }
  let_it_be(:namespace_policies_repository) { create(:project, :custom_repo, files: policy_files) }
  let_it_be(:namespace_security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace: namespace,
      security_policy_management_project: namespace_policies_repository
    )
  end

  let_it_be(:namespace_policy) do
    build(:scan_execution_policy, actions: [
      { scan: 'sast' },
      { scan: 'secret_detection' }
    ])
  end

  let_it_be_with_refind(:project) { create(:project, :small_repo, group: namespace) }
  let_it_be(:policies_repository) { create(:project, :custom_repo, files: policy_files, group: namespace) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policies_repository
    )
  end

  let_it_be(:policy) do
    build(:scan_execution_policy, actions: [
      { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
      { scan: 'secret_detection' },
      { scan: 'container_scanning' },
      { scan: 'sast_iac' },
      { scan: 'dependency_scanning' }
    ])
  end

  let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }
  let_it_be(:namespace_policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [namespace_policy]) }
  let_it_be(:db_project_policy) do
    create(:security_policy, :scan_execution_policy, linked_projects: [project], content: policy.slice(:actions),
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:db_namespace_policy) do
    create(:security_policy, :scan_execution_policy, linked_projects: [project],
      content: namespace_policy.slice(:actions),
      security_orchestration_policy_configuration: namespace_security_orchestration_policy_configuration)
  end

  before do
    allow_next_instance_of(Repository, anything, anything, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end

    allow_next_instance_of(Repository, anything, namespace_policies_repository, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(namespace_policy_yaml)
    end
  end

  shared_examples 'with pipeline source applicable for CI' do
    let_it_be(:source) { 'ondemand_dast_scan' }

    it 'does not modify the config' do
      expect(perform_service).to eq(config)
    end
  end

  shared_examples 'with different scan type' do
    %w[api pipeline merge_request_event schedule].each do |ci_source|
      context "when #{ci_source} pipeline is created and affects CI status of the ref" do
        let(:source) { ci_source }

        it 'collects the injected jobs and metadata in the pipeline context' do
          perform_service
          pipeline_context = pipeline_policy_context.scan_execution_context(ref)
          expect(pipeline_context.job_injected?(extended_job)).to be(true)
          expect(pipeline_context.job_options(extended_job)).to match a_hash_including(:name, :project_id, :sha)
        end

        context 'when config already have jobs with names provided by policies' do
          let(:config) do
            {
              stages: %w[build test release],
              image: 'image:1.0.0',
              'dast-on-demand-0': {
                rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
                needs: [{ job: 'build-job', artifacts: true }]
              },
              'sast-0': {
                rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
                needs: [{ job: 'build-job', artifacts: true }]
              },
              'secret-detection-1': {
                rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
                needs: [{ job: 'build-job', artifacts: true }]
              }
            }
          end

          it 'extends config with additional jobs without overridden values', :aggregate_failures do
            expect(perform_service.keys).to include(expected_jobs)
            expect(perform_service.values).to include(expected_configuration)
            expect(perform_service[extended_job]).not_to include(
              rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
              needs: [{ job: 'build-job', artifacts: true }]
            )
          end
        end

        context 'when test stage is available' do
          let(:config) { { stages: %w[build test release], image: 'image:1.0.0' } }

          it 'does not include scan-policies stage' do
            expect(perform_service[:stages]).to eq(%w[build test release dast])
          end

          it 'extends config with additional jobs' do
            expect(perform_service.keys).to include(expected_jobs)
            expect(perform_service.values).to include(expected_configuration)
          end
        end

        context 'when test stage is not available' do
          let(:scan_policy_stage) { 'scan-policies' }

          context 'when build stage is available' do
            let(:config) { { stages: %w[build not-test release], image: 'image:1.0.0' } }

            it 'includes scan-policies stage after build stage' do
              expect(perform_service[:stages]).to eq(%w[build scan-policies not-test release dast])
            end

            it 'extends config with additional jobs' do
              expect(perform_service.keys).to include(expected_jobs)
              expect(perform_service.values).to include(expected_configuration)
            end
          end

          context 'when build stage is not available' do
            let(:config) { { stages: %w[not-test release], image: 'image:1.0.0' } }

            it 'includes scan-policies stage as a first stage' do
              expect(perform_service[:stages]).to eq(%w[scan-policies not-test release dast])
            end

            context 'when .pre stage is available' do
              let(:config) { { stages: %w[.pre not-test release], image: 'image:1.0.0' } }

              it 'includes scan-policies stage as a first stage after .pre' do
                expect(subject[:stages]).to eq(%w[.pre scan-policies not-test release dast])
              end

              context 'and .pre is before build stage' do
                let(:config) { { stages: %w[.pre build not-test release], image: 'image:1.0.0' } }

                it 'includes scan-policies stage as a first stage after .pre or build' do
                  expect(subject[:stages]).to eq(%w[.pre build scan-policies not-test release dast])
                end
              end

              context 'and .pre is not first in the list and after build stage' do
                let(:config) { { stages: %w[build .pre not-test release], image: 'image:1.0.0' } }

                it 'includes scan-policies stage as a first stage after .pre or build' do
                  expect(subject[:stages]).to eq(%w[build .pre scan-policies not-test release dast])
                end
              end
            end

            context 'when stages are invalid' do
              let(:config) { { stages: { stages: %w[build test deploy] } } }

              it 'does not modify the config' do
                expect(perform_service).to eq(config)
              end
            end

            context 'when .pre stage is not available' do
              it 'includes scan-policies stage as a first stage' do
                expect(subject[:stages]).to eq(%w[scan-policies not-test release dast])
              end
            end

            it 'extends config with additional jobs' do
              expect(perform_service.keys).to include(expected_jobs)
              expect(perform_service.values).to include(expected_configuration)
            end
          end

          context 'when injected jobs use reserved stages (.pre, .post)' do
            let(:config) { { stages: %w[build not-test release], image: 'image:1.0.0' } }

            let(:pipeline_scan_template) do
              {
                'resolve-job': { stage: '.pre', script: ['echo resolve'] },
                'scan-job': { stage: 'test', script: ['echo scan'] },
                'cleanup-job': { stage: '.post', script: ['echo cleanup'] },
                variables: {}
              }
            end

            before do
              allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |service|
                allow(service).to receive(:execute).and_return(
                  pipeline_scan: pipeline_scan_template,
                  on_demand: {},
                  variables: {}
                )
              end
            end

            it 'preserves .pre and .post stages while overriding other stages' do
              result = perform_service

              expect(result[:'resolve-job'][:stage]).to eq('.pre')
              expect(result[:'cleanup-job'][:stage]).to eq('.post')
              expect(result[:'scan-job'][:stage]).to eq('scan-policies')
            end

            it 'still inserts scan-policies stage after build' do
              expect(perform_service[:stages]).to eq(%w[build scan-policies not-test release])
            end
          end
        end
      end
    end
  end

  shared_examples 'when policy is invalid' do
    let_it_be(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy:
      [build(:scan_execution_policy, rules: [{ type: 'pipeline', branches: 'production' }])])
    end

    let_it_be(:namespace_policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy:
      [build(:scan_execution_policy, rules: [{ type: 'pipeline', branches: 'production' }])])
    end

    it 'does not track internal metrics' do
      expect { perform_service }.not_to trigger_internal_events('enforce_scan_execution_policy_in_project')
    end

    it 'does not modify the config', :aggregate_failures do
      expect(config).not_to receive(:deep_merge)
      expect(perform_service).to eq(config)
    end
  end

  context 'when feature is not licensed' do
    it 'does not modify the config' do
      expect(perform_service).to eq(config)
    end

    it 'does not track internal metrics' do
      expect { perform_service }.not_to trigger_internal_events('enforce_scan_execution_policy_in_project')
    end
  end

  context 'when feature is licensed' do
    let(:policies) { { available: true, policies: [policy] } }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'when policy is not applicable on branch from the pipeline' do
      let(:ref) { 'refs/head/another-branch' }

      it 'does not modify the config' do
        expect(perform_service).to eq(config)
      end
    end

    context 'when ref is a tag' do
      let(:ref) { 'refs/tags/v1.1.0' }

      it 'does not modify the config' do
        expect(perform_service).to eq(config)
      end
    end

    context 'when policy only contains scheduled pipelines' do
      let_it_be(:namespace_policy) do
        build(:scan_execution_policy, :with_schedule, actions: [
          { scan: 'sast' }
        ])
      end

      let_it_be(:policy) do
        build(:scan_execution_policy, :with_schedule, actions: [
          { scan: 'secret_detection' }
        ])
      end

      let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }
      let_it_be(:namespace_policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [namespace_policy]) }

      it 'does not modify the config' do
        expect(perform_service).to eq(config)
      end
    end

    context 'when policy is applicable on branch from the pipeline' do
      let(:ref) { 'refs/heads/master' }

      context 'and the project does not have a CI configuration' do
        let(:config) { {} }

        it 'adds a workflow rule' do
          expect(perform_service).to include({ workflow: { rules: [when: 'always'] } })
        end
      end

      context 'when DAST profiles are not found' do
        it 'does not modify the config' do
          expect(perform_service[:'dast-on-demand-0']).to eq({
            allow_failure: true,
            script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false'
          })
        end
      end

      context 'when sast, dast and secret_detection scans are enforced' do
        it 'tracks event' do
          expect { perform_service }
            .to trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'dast' })
            .once
          .and trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'sast' })
            .once
          .and trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'secret_detection' })
            .once
          .and trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'container_scanning' })
            .once
          .and trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'sast_iac' })
            .once
          .and trigger_internal_events('enforce_scan_execution_policy_in_project')
            .with(project: project, additional_properties: { label: 'dependency_scanning' })
            .once
        end
      end

      it_behaves_like 'with pipeline source applicable for CI'
      it_behaves_like 'when policy is invalid'

      context 'when DAST profiles are found' do
        let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project, name: 'Scanner Profile') }
        let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project, name: 'Site Profile') }

        it_behaves_like 'with different scan type' do
          let(:extended_job) { :'dast-on-demand-0' }
          let(:expected_jobs) { starting_with('dast-on-demand-') }
          let(:expected_configuration) do
            {
              stage: 'dast',
              image: {
                name: '$SECURE_ANALYZERS_PREFIX/dast:$DAST_VERSION$DAST_IMAGE_SUFFIX'
              },
              variables: {
                DAST_VERSION: 6,
                SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
                DAST_IMAGE_SUFFIX: ''
              },
              allow_failure: true,
              script: ['/analyze'],
              artifacts: {
                access: 'developer',
                paths: ["gl-dast-*.*"],
                reports: {
                  dast: 'gl-dast-report.json'
                },
                when: 'always'
              },
              dast_configuration: {
                site_profile: dast_site_profile.name,
                scanner_profile: dast_scanner_profile.name
              },
              rules: [
                { if: '$CI_GITLAB_FIPS_MODE == "true"', variables: { DAST_IMAGE_SUFFIX: "-fips" } },
                { when: 'on_success' }
              ]
            }
          end
        end

        it_behaves_like 'with pipeline source applicable for CI'
        it_behaves_like 'when policy is invalid'
      end

      context 'when scan type is secret_detection' do
        it_behaves_like 'with different scan type' do
          let(:extended_job) { :'secret-detection-1' }
          let(:expected_jobs) { starting_with('secret-detection-') }
          let(:expected_configuration) do
            hash_including(
              rules: [
                { if: '$AST_ENABLE_MR_PIPELINES == "true" && $CI_PIPELINE_SOURCE == "merge_request_event"' },
                { if: '$AST_ENABLE_MR_PIPELINES == "true" && $CI_OPEN_MERGE_REQUESTS', when: 'never' },
                { if: '$CI_COMMIT_BRANCH' }
              ],
              script: ["/analyzer run"],
              stage: scan_policy_stage,
              image: '$SECURE_ANALYZERS_PREFIX/secrets:$SECRETS_ANALYZER_VERSION$SECRET_DETECTION_IMAGE_SUFFIX',
              services: [],
              allow_failure: true,
              artifacts: {
                access: 'developer',
                paths: ['gl-secret-detection-report.json'],
                reports: {
                  secret_detection: 'gl-secret-detection-report.json'
                }
              },
              variables: {
                GIT_DEPTH: '50',
                SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
                SECRETS_ANALYZER_VERSION: '7',
                SECRET_DETECTION_IMAGE_SUFFIX: '',
                SECRET_DETECTION_EXCLUDED_PATHS: '',
                SECRET_DETECTION_HISTORIC_SCAN: 'false'
              })
          end
        end
      end

      context 'when scan type is sast is configured for namespace policy project' do
        it_behaves_like 'with different scan type' do
          let(:extended_job) { :'sast-0' }
          let(:expected_jobs) { ending_with('-sast-0') }
          let(:expected_configuration) do
            hash_including(
              artifacts: {
                access: 'developer',
                paths: ['gl-sast-report.json'],
                reports: {
                  sast: 'gl-sast-report.json'
                }
              },
              script: ['/analyzer run'],
              image: { name: '$SAST_ANALYZER_IMAGE' }
            )
          end
        end
      end
    end
  end
end
