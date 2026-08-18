# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyCommitService, feature_category: :source_code_management do
  include RepoHelpers

  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :small_repo) }

    let(:policy_hash) { build(:scan_execution_policy, name: 'Test Policy') }
    let(:input_policy_yaml) { policy_hash.merge(type: 'scan_execution_policy').to_yaml }
    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy_hash]) }
    let(:policy_name) { policy_hash[:name] }

    let(:operation) { :append }
    let(:branch_name) { "update-policy-#{SecureRandom.hex(10)}" }
    let(:params) do
      {
        policy_yaml: input_policy_yaml,
        name: policy_name,
        operation: operation,
        branch_name: branch_name
      }
    end

    subject(:service) do
      described_class.new(container: container, current_user: current_user, params: params)
    end

    around do |example|
      freeze_time { example.run }
    end

    before do
      policy_configuration.clear_memoization(:policy_blob)
    end

    shared_examples 'commits policy to associated project' do
      context 'when policy_yaml is invalid' do
        let(:invalid_input_policy_yaml) do
          <<-YAML
            invalid_name: invalid
            name: 'policy name'
            type: scan_execution_policy
          YAML
        end

        let(:params) { { policy_yaml: invalid_input_policy_yaml, operation: operation } }

        it 'returns error', :aggregate_failures do
          response = service.execute

          expect(response[:status]).to eq(:error)
          expect(response[:message]).to eq("Invalid policy YAML")
          expect(response[:details]).to match_array(["property '/scan_execution_policy/0' is missing required keys: enabled, rules, actions"])
        end
      end

      context 'when defined branch is missing' do
        let(:policy_hash) { build(:scan_execution_policy, name: 'Test Policy', rules: [{ type: 'pipeline' }]) }

        let(:params) { { policy_yaml: input_policy_yaml, operation: operation } }

        it 'returns error', :aggregate_failures do
          response = service.execute

          expect(response[:status]).to eq(:error)
          expect(response[:message]).to eq("Invalid policy")
          expect(response[:details]).to match_array(['Policy cannot be enabled without branch information'])
        end
      end

      context 'when security_orchestration_policies_configuration does not exist for container' do
        let_it_be(:container) { create(:project, :small_repo) }

        it 'does not create new project', :aggregate_failures do
          response = service.execute

          expect(response[:status]).to eq(:error)
          expect(response[:message]).to eq('Security Policy Project does not exist')
        end
      end

      context 'when policy already exists in policy project' do
        let(:policy_file) { { Security::OrchestrationPolicyConfiguration::POLICY_PATH => policy_yaml } }

        around do |example|
          create_and_delete_files(policy_management_project, policy_file) do
            example.run
          end
        end

        before_all do
          policy_configuration.security_policy_management_project.add_developer(current_user)
        end

        context 'append' do
          it 'does not create branch', :aggregate_failures do
            response = service.execute

            expect(response[:status]).to eq(:error)
            expect(response[:message]).to eq("Policy already exists with same name")
          end
        end

        context 'replace' do
          let(:operation) { :replace }
          let(:input_policy_yaml) { build(:scan_execution_policy, name: 'Updated Policy').merge(type: 'scan_execution_policy').to_yaml }
          let(:policy_name) { 'Test Policy' }

          it 'creates branch with updated policy', :aggregate_failures do
            response = service.execute

            expect(response[:status]).to eq(:success)
            expect(response[:message]).to be_nil
            expect(response[:branch]).not_to be_nil

            updated_policy_blob = policy_management_project.repository.blob_data_at(response[:branch], Security::OrchestrationPolicyConfiguration::POLICY_PATH)
            updated_policy_yaml = Gitlab::Config::Loader::Yaml.new(updated_policy_blob).load!
            expect(updated_policy_yaml[:scan_execution_policy][0][:name]).to eq('Updated Policy')
          end

          context 'when policy content is unchanged' do
            let(:input_policy_yaml) { policy_hash.merge(type: 'scan_execution_policy').to_yaml }
            let(:policy_name) { policy_hash[:name] }

            it 'returns error', :aggregate_failures do
              response = service.execute

              expect(response[:status]).to eq(:error)
              expect(response[:message]).to eq('No changes detected in the policy YAML')
            end
          end
        end

        context 'remove' do
          let(:operation) { :remove }

          it 'creates branch with removed policy', :aggregate_failures do
            response = service.execute

            expect(response[:status]).to eq(:success)
            expect(response[:message]).to be_nil
            expect(response[:branch]).not_to be_nil

            updated_policy_blob = policy_management_project.repository.blob_data_at(response[:branch], Security::OrchestrationPolicyConfiguration::POLICY_PATH)
            updated_policy_yaml = Gitlab::Config::Loader::Yaml.new(updated_policy_blob).load!
            expect(updated_policy_yaml[:scan_execution_policy]).to be_empty
          end
        end

        describe 'policy YAML annotation' do
          let(:operation) { :replace }
          let(:experiments) { nil }
          let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy_hash], experiments: experiments) }
          let(:input_policy_yaml) do
            <<~YAML
              ---
              type: scan_execution_policy
              name: Updated Policy
              description: #{policy_hash[:description]}
              enabled: true
              actions:
              - scan: dast
                site_profile: Site Profile
                scanner_profile: Scanner Profile
              rules:
              - type: pipeline
                branches:
                - master
              policy_scope: {}
              metadata: {}
              skip_ci:
                allowed: false
                allowlist:
                  users:
                  - id: #{current_user.id}
            YAML
          end

          shared_examples 'committing the updated policy yaml without annotations' do
            let(:updated_policy_yaml) do
              <<~YAML
                ---
                scan_execution_policy:
                - name: Updated Policy
                  description: #{policy_hash[:description]}
                  enabled: true
                  actions:
                  - scan: dast
                    site_profile: Site Profile
                    scanner_profile: Scanner Profile
                  rules:
                  - type: pipeline
                    branches:
                    - master
                  policy_scope: {}
                  metadata: {}
                  skip_ci:
                    allowed: false
                    allowlist:
                      users:
                      - id: #{current_user.id}
                experiments:
                  annotate_ids:
                    enabled: #{annotation_enabled}
              YAML
            end

            it 'commits the updated policy yaml without annotations', :aggregate_failures do
              response = service.execute

              expect(response[:status]).to eq(:success)
              expect(response[:message]).to be_nil
              expect(response[:branch]).not_to be_nil

              updated_policy_blob = policy_management_project.repository.blob_data_at(response[:branch], Security::OrchestrationPolicyConfiguration::POLICY_PATH)
              expect(updated_policy_blob).to eq(updated_policy_yaml)
            end
          end

          context 'when the experiment option is enabled' do
            let(:experiments) { { annotate_ids: { enabled: true } } }

            let(:annotated_updated_policy_yaml) do
              <<~YAML
                ---
                scan_execution_policy:
                - name: Updated Policy
                  description: #{policy_hash[:description]}
                  enabled: true
                  actions:
                  - scan: dast
                    site_profile: Site Profile
                    scanner_profile: Scanner Profile
                  rules:
                  - type: pipeline
                    branches:
                    - master
                  policy_scope: {}
                  metadata: {}
                  skip_ci:
                    allowed: false
                    allowlist:
                      users:
                      - id: #{current_user.id} # #{current_user.username}
                experiments:
                  annotate_ids:
                    enabled: true
              YAML
            end

            it 'calls the AnnotatePolicyYamlService service' do
              expect_next_instance_of(Security::SecurityOrchestrationPolicies::AnnotatePolicyYamlService) do |instance|
                expect(instance).to receive(:execute).and_call_original
              end

              service.execute
            end

            it 'commits the annotated policy yaml', :aggregate_failures do
              response = service.execute

              expect(response[:status]).to eq(:success)
              expect(response[:message]).to be_nil
              expect(response[:branch]).not_to be_nil

              updated_policy_blob = policy_management_project.repository.blob_data_at(response[:branch], Security::OrchestrationPolicyConfiguration::POLICY_PATH)
              expect(updated_policy_blob).to eq(annotated_updated_policy_yaml)
            end

            it 'logs an info message' do
              expect(::Gitlab::AppJsonLogger)
              .to receive(:info)
              .with(hash_including({
                security_orchestration_policy_configuration_id: policy_configuration.id,
                security_policy_management_project_id: policy_configuration.security_policy_management_project_id,
                operation: :replace,
                user_id: current_user.id,
                message: 'Successfully annotated policy YAML'
              }.deep_stringify_keys))

              service.execute
            end

            it 'tracks internal event for successful annotation' do
              expect { service.execute }
              .to trigger_internal_events('security_policy_yaml_annotated')
              .with(
                user: current_user,
                project: policy_configuration.security_policy_management_project,
                namespace: policy_configuration.security_policy_management_project.namespace,
                additional_properties: {
                  label: operation.to_s
                }
              )
            end

            context 'when annotated policy content is unchanged' do
              let(:input_policy_yaml) do
                <<~YAML
                  ---
                  type: scan_execution_policy
                  name: #{policy_hash[:name]}
                  description: #{policy_hash[:description]}
                  enabled: true
                  actions:
                  - scan: dast
                    site_profile: Site Profile
                    scanner_profile: Scanner Profile
                  rules:
                  - type: pipeline
                    branches:
                    - master
                YAML
              end

              let(:policy_name) { policy_hash[:name] }

              let(:policy_yaml) do
                <<~YAML
                  ---
                  scan_execution_policy:
                  - name: #{policy_hash[:name]}
                    description: #{policy_hash[:description]}
                    enabled: true
                    actions:
                    - scan: dast
                      site_profile: Site Profile
                      scanner_profile: Scanner Profile
                    rules:
                    - type: pipeline
                      branches:
                      - master
                  experiments:
                    annotate_ids:
                      enabled: true
                YAML
              end

              it 'returns error when policy content is unchanged', :aggregate_failures do
                response = service.execute

                expect(response[:status]).to eq(:error)
                expect(response[:message]).to eq('No changes detected in the policy YAML')
              end
            end

            context 'when already annotated policy content is unchanged' do
              let(:input_policy_yaml) do
                <<~YAML
                  ---
                  type: scan_execution_policy
                  name: #{policy_hash[:name]}
                  description: #{policy_hash[:description]}
                  enabled: true
                  actions:
                  - scan: dast
                    site_profile: Site Profile
                    scanner_profile: Scanner Profile
                  rules:
                  - type: pipeline
                    branches:
                    - master
                  skip_ci:
                    allowed: false
                    allowlist:
                      users:
                      - id: #{current_user.id}
                YAML
              end

              let(:policy_name) { policy_hash[:name] }

              let(:policy_yaml) do
                <<~YAML
                  ---
                  scan_execution_policy:
                  - name: #{policy_hash[:name]}
                    description: #{policy_hash[:description]}
                    enabled: true
                    actions:
                    - scan: dast
                      site_profile: Site Profile
                      scanner_profile: Scanner Profile
                    rules:
                    - type: pipeline
                      branches:
                      - master
                    skip_ci:
                      allowed: false
                      allowlist:
                        users:
                        - id: #{current_user.id} # #{current_user.username}
                  experiments:
                    annotate_ids:
                      enabled: true
                YAML
              end

              it 'returns error when already annotated policy content is unchanged', :aggregate_failures do
                response = service.execute

                expect(response[:status]).to eq(:error)
                expect(response[:message]).to eq('No changes detected in the policy YAML')
              end
            end

            context 'when the AnnotatePolicyYamlService fails' do
              let(:annotation_enabled) { true }

              before do
                allow_next_instance_of(Security::SecurityOrchestrationPolicies::AnnotatePolicyYamlService) do |instance|
                  allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'annotation error'))
                end
              end

              it 'calls the AnnotatePolicyYamlService' do
                expect(::Security::SecurityOrchestrationPolicies::AnnotatePolicyYamlService).to receive(:new)

                service.execute
              end

              it 'does not track internal event for annotation' do
                expect { service.execute }.not_to trigger_internal_events('security_policy_yaml_annotated')
              end

              it_behaves_like 'committing the updated policy yaml without annotations'
            end
          end

          context 'when the experiment option is disabled' do
            let(:experiments) { { annotate_ids: { enabled: false } } }
            let(:annotation_enabled) { false }

            it 'does not call the AnnotatePolicyYamlService' do
              expect(::Security::SecurityOrchestrationPolicies::AnnotatePolicyYamlService).not_to receive(:new)

              service.execute
            end

            it_behaves_like 'committing the updated policy yaml without annotations'
          end

          context 'when the experiment option is not defined' do
            let(:experiments) { { annotate_ids: {} } }

            it 'returns error', :aggregate_failures do
              response = service.execute
              expect(response[:status]).to eq(:error)
              expect(response[:message]).to eq("Invalid policy YAML")
              expect(response[:http_status]).to eq(:bad_request)
            end
          end
        end
      end

      context 'with branch_name as parameter' do
        let(:branch_name) { 'main' }
        let(:params) { { policy_yaml: input_policy_yaml, operation: operation, branch_name: branch_name } }

        it 'returns error', :aggregate_failures do
          response = service.execute
          expect(response[:status]).to eq(:error)
          expect(response[:message]).to eq("You are not allowed to push into this branch")
          expect(response[:http_status]).to eq(:bad_request)
        end

        context 'with user as a member of security project' do
          before_all do
            policy_configuration.security_policy_management_project.add_developer(current_user)
          end

          it 'returns success', :aggregate_failures do
            response = service.execute
            expect(response[:status]).to eq(:success)
            expect(response[:message]).to be_nil
            expect(response[:branch]).to eq(branch_name)
          end
        end
      end
    end

    context 'when service is used for project' do
      let_it_be(:container) { project }
      let_it_be(:current_user) { project.first_owner }

      let_it_be(:policy_management_project) { create(:project, :small_repo, creator: current_user) }
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, security_policy_management_project: policy_management_project, project: project) }

      before do
        policy_configuration.invalidate_policy_yaml_cache
      end

      it_behaves_like 'commits policy to associated project'
    end

    context 'when service is used for namespace' do
      let_it_be(:container) { group }
      let_it_be(:current_user) { create(:user, owner_of: group) }

      let_it_be(:policy_management_project) { create(:project, :small_repo, creator: current_user) }
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, security_policy_management_project: policy_management_project, namespace: group) }

      before do
        policy_configuration.invalidate_policy_yaml_cache
      end

      it_behaves_like 'commits policy to associated project'
    end
  end
end
