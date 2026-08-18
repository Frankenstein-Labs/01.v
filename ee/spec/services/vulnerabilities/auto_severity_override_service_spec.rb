# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AutoSeverityOverrideService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:cve_identifier) { 'CVE-2021-44228' }
  let(:location_file) { 'app/models/user.rb' }
  let!(:finding) do
    create(:vulnerabilities_finding,
      :detected,
      :with_cve,
      severity: :high,
      project: project,
      cve_value: cve_identifier,
      location: {
        'file' => location_file,
        'start_line' => 5,
        'end_line' => 6
      })
  end

  let!(:vulnerability) { finding.vulnerability }
  let(:vulnerability_ids) { [vulnerability.id] }

  let(:service) { described_class.new(pipeline, vulnerability_ids) }

  subject(:execute) { service.execute }

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow(Ability).to receive(:allowed?).with(anything, :create_vulnerability_state_transition,
      project).and_return(true)
  end

  describe '#execute' do
    context 'when there are no policies' do
      it 'returns success with count 0' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:count]).to eq(0)
      end

      it 'does not track any events' do
        expect { execute }
          .not_to trigger_internal_events(
            'evaluate_vulnerability_management_policy_in_project',
            described_class::OVERRIDE_EVENT_NAME
          )
      end
    end

    context 'when there are severity override policies' do
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
              'type' => 'severity_override',
              'severity_override_operation' => 'set',
              'severity_override_value' => 'low'
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

      shared_examples_for 'vulnerability severity gets overridden' do |expected_severity|
        it 'overrides matching vulnerability severity' do
          expect { execute }.to change { vulnerability.reload.severity }.from('high').to(expected_severity)
        end

        it 'creates severity override record' do
          expect { execute }.to change { Vulnerabilities::SeverityOverride.count }.by(1)

          override = Vulnerabilities::SeverityOverride.last
          expect(override.vulnerability_id).to eq(vulnerability.id)
          expect(override.original_severity).to eq('high')
          expect(override.new_severity).to eq(expected_severity)
          expect(override.triggered_by_policy).to be(true)
          expect(override.security_policy_id).to eq(policy.id)
          expect(override.author_id).to eq(bot_user.id)
        end

        it 'updates finding severity' do
          execute

          expect(finding.reload.severity).to eq(expected_severity)
        end

        it 'creates system note' do
          expect { execute }.to change { vulnerability.notes.system.count }.by(1)

          note = vulnerability.notes.system.last
          expect(note.note).to include('changed vulnerability severity')
          expect(note.note).to include(expected_severity.titleize)
          expect(note.note).to include('Auto-overridden by the vulnerability management policy')
          expect(note.note).to include(policy.name)
        end

        it 'returns success with correct count' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)
        end

        it 'logs instrumentation with correct information' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              class: 'Vulnerabilities::AutoSeverityOverrideService',
              project_id: project.id,
              pipeline_id: pipeline.id,
              policy_auto_severity_override_vulnerabilities_overridden: 1,
              policy_auto_severity_override_duration_s: be_a(Float)
            )
          )

          execute
        end
      end

      shared_examples_for 'vulnerability severity stays unchanged' do
        it 'does not change the vulnerability severity' do
          expect { execute }.not_to change { vulnerability.reload.severity }
        end

        it 'returns success with zero results' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(0)
        end
      end

      context 'when tracking internal events' do
        context 'when policies are present and vulnerabilities match' do
          it 'tracks the evaluate event with auto_severity_override label' do
            expect { execute }
              .to trigger_internal_events('evaluate_vulnerability_management_policy_in_project')
              .with(project: project, additional_properties: { label: 'auto_severity_override' })
          end

          it 'tracks the dedicated severity override event with vulnerability count' do
            expect { execute }
              .to trigger_internal_events(described_class::OVERRIDE_EVENT_NAME)
              .with(project: project, additional_properties: { value: 1 })
          end
        end

        context 'when policies are present but no vulnerabilities match' do
          let(:rule_content) do
            {
              'criteria' => [
                {
                  'type' => 'file_path',
                  'value' => 'no/match/here.rb'
                }
              ]
            }
          end

          it 'tracks the evaluate event but not the dedicated event' do
            expect { execute }
              .to trigger_internal_events('evaluate_vulnerability_management_policy_in_project')
              .with(project: project, additional_properties: { label: 'auto_severity_override' })
              .and not_trigger_internal_events(described_class::OVERRIDE_EVENT_NAME)
          end
        end
      end

      context 'when licensed feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'vulnerability severity stays unchanged'

        it 'does not track any events' do
          expect { execute }
            .not_to trigger_internal_events(
              'evaluate_vulnerability_management_policy_in_project',
              described_class::OVERRIDE_EVENT_NAME
            )
        end
      end

      context 'when bot user is not authorized' do
        before do
          allow(Ability).to receive(:allowed?).with(anything, :create_vulnerability_state_transition,
            project).and_return(false)
        end

        it_behaves_like 'vulnerability severity stays unchanged'

        it 'tracks the evaluate event but not the dedicated event' do
          # track_policy_evaluation fires before the authorized? guard - consistent with AutoDismissService.
          # The dedicated event is only fired after overrides are applied, which requires authorization.
          expect { execute }
            .to trigger_internal_events('evaluate_vulnerability_management_policy_in_project')
            .with(project: project, additional_properties: { label: 'auto_severity_override' })
            .and not_trigger_internal_events(described_class::OVERRIDE_EVENT_NAME)
        end
      end

      context 'with set operation' do
        it_behaves_like 'vulnerability severity gets overridden', 'low'

        context 'when new severity is the same as current severity' do
          let(:policy_content) do
            {
              'actions' => [
                {
                  'type' => 'severity_override',
                  'severity_override_operation' => 'set',
                  'severity_override_value' => 'high'
                }
              ]
            }
          end

          it_behaves_like 'vulnerability severity stays unchanged'
        end
      end

      context 'with increase operation' do
        let(:policy_content) do
          {
            'actions' => [
              {
                'type' => 'severity_override',
                'severity_override_operation' => 'increase'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability severity gets overridden', 'critical'

        context 'when already at critical (max)' do
          before do
            vulnerability.update!(severity: :critical)
            finding.update!(severity: :critical)
          end

          it_behaves_like 'vulnerability severity stays unchanged'
        end
      end

      context 'with decrease operation' do
        let(:policy_content) do
          {
            'actions' => [
              {
                'type' => 'severity_override',
                'severity_override_operation' => 'decrease'
              }
            ]
          }
        end

        it_behaves_like 'vulnerability severity gets overridden', 'medium'

        context 'when already at info (min)' do
          before do
            vulnerability.update!(severity: :info)
            finding.update!(severity: :info)
          end

          it_behaves_like 'vulnerability severity stays unchanged'
        end
      end

      context 'when vulnerability severity is unknown' do
        before do
          vulnerability.update!(severity: :unknown)
          finding.update!(severity: :unknown)
        end

        context 'with increase operation' do
          let(:policy_content) do
            {
              'actions' => [
                {
                  'type' => 'severity_override',
                  'severity_override_operation' => 'increase'
                }
              ]
            }
          end

          it_behaves_like 'vulnerability severity stays unchanged'
        end

        context 'with decrease operation' do
          let(:policy_content) do
            {
              'actions' => [
                {
                  'type' => 'severity_override',
                  'severity_override_operation' => 'decrease'
                }
              ]
            }
          end

          it_behaves_like 'vulnerability severity stays unchanged'
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

        it_behaves_like 'vulnerability severity gets overridden', 'low'

        context 'when criteria does not match' do
          let(:location_file) { 'src/main.c' }

          it_behaves_like 'vulnerability severity stays unchanged'
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

        it_behaves_like 'vulnerability severity gets overridden', 'low'

        context 'when identifier does not match' do
          let(:cve_identifier) { 'CVE-2024-12345' }

          it_behaves_like 'vulnerability severity stays unchanged'
        end
      end

      context 'with multiple criteria (AND logic)' do
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

        it_behaves_like 'vulnerability severity gets overridden', 'low'

        context 'when not all criteria match' do
          let(:cve_identifier) { 'CVE-2024-12345' }

          it_behaves_like 'vulnerability severity stays unchanged'
        end
      end

      context 'with manual override precedence' do
        before do
          # Simulate a vulnerability that was manually raised from high to critical;
          # the policy (set to low) should not override it because a manual override exists.
          vulnerability.update!(severity: :critical)
          finding.update!(severity: :critical)
          create(:vulnerability_severity_override,
            vulnerability: vulnerability,
            project: project,
            author: user,
            original_severity: :high,
            new_severity: :critical,
            triggered_by_policy: false)
        end

        it_behaves_like 'vulnerability severity stays unchanged'
      end

      context 'with competing policies' do
        let!(:policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration,
            severity_override_operation: 'decrease',
            linked_projects: [project])
        end

        let!(:increase_policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
            severity_override_operation: 'increase',
            policy_index: 1,
            linked_projects: [project])
        end

        let!(:increase_rule) do
          create(:vulnerability_management_policy_rule, :detected,
            security_policy: increase_policy,
            content: rule_content)
        end

        it 'picks the highest severity when both policies match' do
          expect { execute }.to change { vulnerability.reload.severity }.from('high').to('critical')
        end
      end

      context 'when AUTO_OVERRIDE_LIMIT is exceeded' do
        let_it_be(:vulnerability2) do
          create(:vulnerability, :with_findings, :detected, :high_severity, project: project)
        end

        let(:vulnerability_ids) { [vulnerability.id, vulnerability2.id] }

        before do
          stub_const("#{described_class}::AUTO_OVERRIDE_LIMIT", 1)
        end

        it 'respects the budget limit' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)
        end
      end

      context 'when ActiveRecord error occurs' do
        before do
          allow(Vulnerabilities::SeverityOverride)
            .to receive(:insert_all!).and_raise(ActiveRecord::ActiveRecordError, 'Database error')
        end

        it 'returns error response' do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq('ActiveRecord error')
          expect(result.payload[:exception]).to be_a(ActiveRecord::ActiveRecordError)
        end
      end

      context 'with audit events' do
        it 'creates audit events for severity changes' do
          expect_next_instance_of(Vulnerabilities::SeverityOverrideAuditService) do |audit_service|
            expect(audit_service).to receive(:execute)
          end

          execute
        end
      end

      context 'when budget is exhausted across batches' do
        let!(:finding2) do
          create(:vulnerabilities_finding,
            :detected,
            :with_cve,
            severity: :high,
            project: project,
            cve_value: cve_identifier,
            location: {
              'file' => location_file,
              'start_line' => 10,
              'end_line' => 11
            })
        end

        let!(:vulnerability2) { finding2.vulnerability }
        let(:vulnerability_ids) { [vulnerability.id, vulnerability2.id] }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
          stub_const("#{described_class}::AUTO_OVERRIDE_LIMIT", 1)
        end

        it 'breaks out of each_batch when remaining budget is zero' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)
        end
      end

      context 'when budget is exhausted within a single batch' do
        let!(:finding2) do
          create(:vulnerabilities_finding,
            :detected,
            :with_cve,
            severity: :high,
            project: project,
            cve_value: cve_identifier,
            location: {
              'file' => location_file,
              'start_line' => 10,
              'end_line' => 11
            })
        end

        let!(:vulnerability2) { finding2.vulnerability }
        let(:vulnerability_ids) { [vulnerability.id, vulnerability2.id] }

        before do
          stub_const("#{described_class}::AUTO_OVERRIDE_LIMIT", 1)
        end

        it 'stops collecting override candidates when budget is reached' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)

          overridden_count = Vulnerabilities::SeverityOverride.where(
            vulnerability_id: vulnerability_ids
          ).count
          expect(overridden_count).to eq(1)
        end
      end

      context 'when turn_off_vulnerability_read_create_db_trigger_function is disabled' do
        before do
          stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
        end

        it 'updates vulnerability reads via update_all instead of UpsertService' do
          expect(Vulnerabilities::Reads::UpsertService).not_to receive(:new)

          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(1)
          expect(Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id).severity).to eq('low')
        end
      end

      context 'when inserting notes fails' do
        before do
          allow(Note).to receive(:insert_all!).and_raise(ActiveRecord::ActiveRecordError, 'insert failed')
        end

        it 'logs error and does not raise' do
          expect(Gitlab::AppJsonLogger).to receive(:error).with(
            hash_including(
              message: 'Failed to insert system notes for auto-severity-override',
              project_id: project.id,
              pipeline_id: pipeline.id,
              exception: 'insert failed'
            )
          )

          expect { execute }.not_to raise_error
        end

        it 'still overrides severity despite note failure' do
          expect { execute }.to change { vulnerability.reload.severity }.from('high').to('low')
        end
      end

      context 'when auditing severity changes fails' do
        before do
          allow_next_instance_of(Vulnerabilities::SeverityOverrideAuditService) do |audit_service|
            allow(audit_service).to receive(:execute).and_raise(StandardError, 'audit failed')
          end
        end

        it 'logs error and does not raise' do
          expect(Gitlab::AppJsonLogger).to receive(:error).with(
            hash_including(
              message: 'Failed to create audit events for auto-severity-override',
              project_id: project.id,
              pipeline_id: pipeline.id,
              exception_class: 'StandardError',
              exception: 'audit failed'
            )
          )

          expect { execute }.not_to raise_error
        end

        it 'still overrides severity despite audit failure' do
          expect { execute }.to change { vulnerability.reload.severity }.from('high').to('low')
        end
      end
    end
  end
end
