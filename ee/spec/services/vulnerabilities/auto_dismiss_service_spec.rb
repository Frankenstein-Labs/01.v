# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AutoDismissService, :elastic, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:cve_identifier) { 'CVE-2021-44228' }
  let(:location_file) { 'app/models/user.rb' }
  let!(:finding) do
    create(:vulnerabilities_finding,
      :detected,
      :with_cve,
      project: project,
      cve_value: cve_identifier,
      location: {
        'file' => location_file,
        'start_line' => 5,
        'end_line' => 6
      })
  end

  let!(:vulnerability) { finding.vulnerability }
  let(:vulnerability_read) { vulnerability.vulnerability_read }
  let(:vulnerability_ids) { [vulnerability.id] }

  let(:service) { described_class.new(pipeline, vulnerability_ids) }

  subject(:execute) { service.execute }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    context 'when there are no policies' do
      it 'returns success with count 0' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:count]).to eq(0)
      end
    end

    context 'when there are auto-dismiss policies' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      let!(:policy) do
        create(:security_policy, :vulnerability_management_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          content: policy_content,
          linked_projects: [project])
      end

      let!(:policy_rule) do
        create(:vulnerability_management_policy_rule, :detected,
          security_policy: policy,
          content: rule_content)
      end

      let(:policy_content) do
        {
          'actions' => [
            {
              'type' => 'auto_dismiss',
              'dismissal_reason' => 'used_in_tests'
            }
          ]
        }
      end

      let(:rule_content) do
        {
          'criteria' => [
            {
              'type' => 'file_path',
              'value' => location_file
            }
          ]
        }
      end

      let_it_be(:bot_user) { create(:user, :security_policy_bot, guest_of: project) }
      let(:ability_allowed) { true }

      before do
        allow(Ability).to receive(:allowed?).and_return(true)
        allow(Ability).to receive(:allowed?).with(bot_user, :create_vulnerability_state_transition,
          project).and_return(ability_allowed)
      end

      shared_examples_for 'vulnerability gets dismissed' do
        it 'dismisses matching vulnerabilities' do
          expect { execute }.to change { vulnerability.reload.state }.from('detected').to('dismissed')
        end

        it 'creates state transition with correct dismissal reason' do
          execute

          state_transition = vulnerability.state_transitions.last
          expect(state_transition.dismissal_reason).to eq('used_in_tests')
          expect(state_transition.comment).to include('Auto-dismissed by the vulnerability management policy')
          expect(state_transition.vulnerability_occurrence_id).to eq(vulnerability_read.vulnerability_occurrence_id)
        end

        it 'updates vulnerability read with dismissal reason' do
          execute

          vulnerability_read.reload
          expect(vulnerability_read.state).to eq('dismissed')
          expect(vulnerability_read.dismissal_reason).to eq('used_in_tests')
        end

        it 'creates system note' do
          expect { execute }.to change { vulnerability.notes.system.count }.by(1)

          note = vulnerability.notes.system.last
          expect(note.note).to include('changed vulnerability status to Dismissed: Used In Tests')
        end

        it 'returns success with correct count' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)
        end

        it_behaves_like 'policy metrics histogram', described_class::HISTOGRAM

        it 'logs instrumentation with correct information' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              class: 'Vulnerabilities::AutoDismissService',
              project_id: project.id,
              pipeline_id: pipeline.id,
              policy_auto_dismiss_vulnerabilities_processed: 1,
              policy_auto_dismiss_vulnerabilities_dismissed: 1,
              policy_auto_dismiss_duration_s: be_a(Float)
            )
          )

          execute
        end

        it_behaves_like 'sync vulnerabilities changes to ES' do
          let(:expected_vulnerabilities) { vulnerability.vulnerability_read }

          subject { execute }
        end

        context 'when webhook events are enabled for project' do
          before do
            allow(project).to receive(:has_active_hooks?).with(:vulnerability_hooks).and_return(true)
          end

          it 'triggers webhook events for dismissed vulnerabilities' do
            expect_any_instance_of(Vulnerability) do |instance|
              expect(instance).to receive(:trigger_webhook_event)
            end

            execute
          end
        end

        describe 'internal event tracking' do
          let(:event) { 'auto_dismiss_vulnerability_in_project_after_pipeline_run_if_policy_is_set' }
          let(:distinct_count_weekly) do
            'redis_hll_counters.count_distinct_project_id_from_vulnerability_auto_dismiss_weekly'
          end

          let(:distinct_count_monthly) do
            'redis_hll_counters.count_distinct_project_id_from_vulnerability_auto_dismiss_monthly'
          end

          let(:total_count_weekly) do
            'counts.count_total_auto_dismiss_vulnerability_in_project_after_pipeline_run_if_policy_is_set_weekly'
          end

          let(:total_count_monthly) do
            'counts.count_total_auto_dismiss_vulnerability_in_project_after_pipeline_run_if_policy_is_set_monthly'
          end

          let(:total_count) do
            'counts.count_total_auto_dismiss_vulnerability_in_project_after_pipeline_run_if_policy_is_set'
          end

          let(:additional_properties) do
            {
              value: vulnerability_ids.size
            }
          end

          it 'tracks internal events', :clean_gitlab_redis_shared_state, :aggregate_failures do
            expect { execute }
              .to trigger_internal_events(event)
              .with(
                project: project,
                namespace: project.namespace,
                additional_properties: additional_properties
              ).and increment_usage_metrics(distinct_count_weekly).by(1)
                .and increment_usage_metrics(distinct_count_monthly).by(1)
                .and increment_usage_metrics(total_count_weekly).by(1)
                .and increment_usage_metrics(total_count_monthly).by(1)
                .and increment_usage_metrics(total_count).by(1)
          end
        end

        describe 'policy evaluation tracking' do
          let(:evaluation_event) { 'evaluate_vulnerability_management_policy_in_project' }
          let(:evaluation_project_metric_weekly) do
            'redis_hll_counters.count_distinct_project_id_from_evaluate_vulnerability_management_policy_weekly'
          end

          let(:evaluation_project_metric_monthly) do
            'redis_hll_counters.count_distinct_project_id_from_evaluate_vulnerability_management_policy_monthly'
          end

          it 'tracks policy evaluation event and increments metrics',
            :clean_gitlab_redis_shared_state, :aggregate_failures do
            expect { execute }
              .to trigger_internal_events(evaluation_event)
              .with(
                project: project,
                namespace: project.namespace,
                additional_properties: { label: 'auto_dismiss' }
              ).and increment_usage_metrics(evaluation_project_metric_weekly).by(1)
                .and increment_usage_metrics(evaluation_project_metric_monthly).by(1)
          end
        end

        context 'when licensed feature is not available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it 'returns success with count 0 without processing' do
            result = execute

            expect(result).to be_success
            expect(result.payload[:count]).to eq(0)
            expect(vulnerability.reload.state).to eq('detected')
          end
        end

        describe 'error cases' do
          context 'when bot user does not have permission' do
            let(:ability_allowed) { false }

            it 'returns error' do
              result = execute

              expect(result).to be_error
              expect(result.reason).to eq('Bot user does not have permission to create state transitions')
            end
          end

          context 'when ActiveRecord error occurs' do
            before do
              allow(Vulnerabilities::StateTransition)
                .to receive(:insert_all!).and_raise(ActiveRecord::ActiveRecordError, 'Database error')
            end

            it 'returns error response' do
              result = execute

              expect(result).to be_error
              expect(result.reason).to eq('ActiveRecord error')
              expect(result.payload[:exception]).to be_a(ActiveRecord::ActiveRecordError)
            end
          end
        end
      end

      shared_examples_for 'vulnerability stays detected' do
        it 'does not dismiss the vulnerability' do
          expect { execute }.not_to change { vulnerability.reload.state }.from('detected')
        end

        it 'returns success with zero results' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(0)
        end
      end

      context 'with file_path criteria' do
        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'file_path',
                'value' => '**/*.rb'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability gets dismissed'

        context 'when criteria does not match' do
          let(:location_file) { 'src/main.c' }

          it_behaves_like 'vulnerability stays detected'
        end
      end

      context 'with directory criteria' do
        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'directory',
                'value' => 'app/**/*'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability gets dismissed'

        context 'when criteria does not match' do
          let(:location_file) { 'lib/services/user_service.rb' }

          it_behaves_like 'vulnerability stays detected'
        end
      end

      context 'with identifier criteria' do
        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'identifier',
                'value' => 'CVE-2021-*'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability gets dismissed'

        context 'when identifier does not match' do
          let(:cve_identifier) { 'CVE-2024-12345' }

          it_behaves_like 'vulnerability stays detected'
        end
      end

      context 'with multiple criteria' do
        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'file_path',
                'value' => '**/*.rb'
              },
              {
                'type' => 'identifier',
                'value' => 'CVE-2021-*'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability gets dismissed'

        context 'when not all criteria match' do
          let(:cve_identifier) { 'CVE-2024-12345' }

          it_behaves_like 'vulnerability stays detected'
        end
      end

      context 'with different dismissal reasons' do
        shared_examples 'dismisses with correct reason' do |reason|
          context "with dismissal reason #{reason}" do
            let(:policy_content) do
              {
                'actions' => [
                  {
                    'type' => 'auto_dismiss',
                    'dismissal_reason' => reason
                  }
                ]
              }
            end

            it "dismisses with #{reason} reason" do
              execute

              state_transition = vulnerability.state_transitions.last
              expect(state_transition.dismissal_reason).to eq(reason)

              vulnerability_read.reload
              expect(vulnerability_read.dismissal_reason).to eq(reason)
            end

            context 'when feature flag "turn_off_vulnerability_read_create_db_trigger_function" is disabled' do
              before do
                stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
              end

              it "updates vulnerability reads with #{reason} reason" do
                execute

                vulnerability_read.reload
                expect(vulnerability_read.dismissal_reason).to eq(reason)
              end
            end
          end
        end

        include_examples 'dismisses with correct reason', 'acceptable_risk'
        include_examples 'dismisses with correct reason', 'false_positive'
        include_examples 'dismisses with correct reason', 'mitigating_control'
        include_examples 'dismisses with correct reason', 'used_in_tests'
        include_examples 'dismisses with correct reason', 'not_applicable'
      end

      context 'with multiple policies having different dismissal reasons' do
        # Vulnerability 1: in test/ directory, should be dismissed with 'used_in_tests'
        # Vulnerability 2: in vendor/ directory, should be dismissed with 'not_applicable'
        let(:location_file) { 'test/example_spec.rb' }

        let(:policy_content) do
          {
            'actions' => [
              {
                'type' => 'auto_dismiss',
                'dismissal_reason' => 'used_in_tests'
              }
            ]
          }
        end

        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'directory',
                'value' => 'test'
              }
            ]
          }
        end

        let_it_be(:vendor_finding) do
          create(:vulnerabilities_finding,
            :detected,
            :with_cve,
            project: project,
            cve_value: 'CVE-2024-99999',
            location: {
              'file' => 'vendor/parser.py',
              'start_line' => 1,
              'end_line' => 2
            })
        end

        let_it_be(:vendor_vulnerability) { vendor_finding.vulnerability }
        let(:vendor_vulnerability_read) { vendor_vulnerability.vulnerability_read }
        let(:vulnerability_ids) { [vulnerability.id, vendor_vulnerability.id] }

        let_it_be(:second_policy) do
          create(:security_policy, :vulnerability_management_policy,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration,
            policy_index: 1,
            content: {
              'actions' => [
                {
                  'type' => 'auto_dismiss',
                  'dismissal_reason' => 'not_applicable'
                }
              ]
            },
            linked_projects: [project])
        end

        let_it_be(:second_policy_rule) do
          create(:vulnerability_management_policy_rule, :detected,
            security_policy: second_policy,
            content: {
              'criteria' => [
                {
                  'type' => 'directory',
                  'value' => 'vendor'
                }
              ]
            })
        end

        it 'assigns the correct dismissal reason from each matching policy' do
          execute

          expect(vulnerability.reload.state).to eq('dismissed')
          expect(vulnerability_read.reload.dismissal_reason).to eq('used_in_tests')

          expect(vendor_vulnerability.reload.state).to eq('dismissed')
          expect(vendor_vulnerability_read.reload.dismissal_reason).to eq('not_applicable')
        end

        it 'creates state transitions with per-vulnerability dismissal reasons' do
          execute

          test_transition = vulnerability.state_transitions.last
          expect(test_transition.dismissal_reason).to eq('used_in_tests')

          vendor_transition = vendor_vulnerability.state_transitions.last
          expect(vendor_transition.dismissal_reason).to eq('not_applicable')
        end

        it 'creates system notes with per-vulnerability dismissal reasons' do
          execute

          test_note = vulnerability.notes.system.last
          expect(test_note.note).to include('Used In Tests')

          vendor_note = vendor_vulnerability.notes.system.last
          expect(vendor_note.note).to include('Not Applicable')
        end

        context 'when a vulnerability matches no rule' do
          let_it_be(:unmatched_finding) do
            create(:vulnerabilities_finding,
              :detected,
              :with_cve,
              project: project,
              cve_value: 'CVE-2024-11111',
              location: { 'file' => 'unmatched/path.rb', 'start_line' => 1, 'end_line' => 2 })
          end

          let_it_be(:unmatched_vulnerability) { unmatched_finding.vulnerability }
          let(:vulnerability_ids) { [vulnerability.id, vendor_vulnerability.id, unmatched_vulnerability.id] }

          it 'does not dismiss the unmatched vulnerability' do
            execute

            expect(unmatched_vulnerability.reload.state).to eq('detected')
          end

          it 'still dismisses the matched vulnerabilities with correct reasons' do
            execute

            expect(vulnerability.reload.state).to eq('dismissed')
            expect(vulnerability_read.reload.dismissal_reason).to eq('used_in_tests')

            expect(vendor_vulnerability.reload.state).to eq('dismissed')
            expect(vendor_vulnerability_read.reload.dismissal_reason).to eq('not_applicable')
          end
        end
      end

      %i[dismissed resolved].each do |state|
        context "when vulnerability is already #{state}" do
          before do
            vulnerability.update!(state: state)
          end

          it 'does not process already dismissed vulnerabilities' do
            result = execute

            expect(result).to be_success
            expect(result.payload[:count]).to eq(0)
          end

          it 'does not log instrumentation' do
            expect(Gitlab::AppJsonLogger).not_to receive(:info)

            execute
          end
        end
      end

      context 'when AUTO_DISMISS_LIMIT is exceeded' do
        let_it_be(:vulnerability2) do
          create(:vulnerability, :with_findings, :detected, :high_severity, project: project)
        end

        let(:vulnerability_ids) { [vulnerability.id, vulnerability2.id] }

        before do
          stub_const("#{described_class}::AUTO_DISMISS_LIMIT", 1)
        end

        it 'respects the budget limit' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)

          expect(vulnerability.reload.state).to eq('dismissed')
          expect(vulnerability2.reload.state).to eq('detected')
        end
      end

      context 'with batching functionality' do
        let!(:findings) do
          create_list(:vulnerabilities_finding, 5,
            :detected,
            :with_cve,
            project: project,
            cve_value: cve_identifier,
            location: {
              'file' => location_file,
              'start_line' => 5,
              'end_line' => 6
            })
        end

        let_it_be(:non_matching_findings) { create_list(:vulnerabilities_finding, 3, :detected, project: project) }

        let!(:vulnerabilities) { findings.map(&:vulnerability) }
        let(:vulnerability_ids) { vulnerabilities.map(&:id) + non_matching_findings.map(&:vulnerability_id) }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
        end

        it 'processes vulnerabilities in batches' do
          expect(service).to receive(:process_batch).exactly(4).times.and_call_original

          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(5)

          vulnerabilities.each do |vulnerability|
            expect(vulnerability.reload.state).to eq('dismissed')
          end
        end

        it 'respects budget across batches' do
          stub_const("#{described_class}::AUTO_DISMISS_LIMIT", 3)

          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(3)

          dismissed_count = vulnerabilities.map(&:reload).count { |v| v.state == 'dismissed' }
          expect(dismissed_count).to eq(3)
        end

        it 'stops processing when budget is exhausted' do
          stub_const("#{described_class}::AUTO_DISMISS_LIMIT", 2)

          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(2)

          dismissed_count = vulnerabilities.map(&:reload).count { |v| v.state == 'dismissed' }
          expect(dismissed_count).to eq(2)
        end

        it_behaves_like 'policy metrics histogram', described_class::HISTOGRAM

        it 'logs instrumentation with correct counts for multiple vulnerabilities' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              class: described_class.name,
              project_id: project.id,
              pipeline_id: pipeline.id,
              policy_auto_dismiss_vulnerabilities_processed: 8,
              policy_auto_dismiss_vulnerabilities_dismissed: 5,
              policy_auto_dismiss_duration_s: be_a(Float) & be_positive
            )
          )

          execute
        end
      end

      describe '#dismissal_reason_for_rule' do
        context 'when rule is nil' do
          it 'falls back to the first policy dismissal reason' do
            result = service.send(:dismissal_reason_for_rule, nil)

            expect(result).to eq(policy.dismissal_reason)
          end
        end
      end
    end
  end
end
