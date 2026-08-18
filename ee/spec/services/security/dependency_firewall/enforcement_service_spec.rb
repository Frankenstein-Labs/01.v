# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::EnforcementService, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  # Counters are buffered, so assertions about persisted rows have to flush first.
  def flush_activity_stats
    Security::DependencyFirewall::FlushActivityStatsWriteBufferCronWorker.new.perform
  end

  # Creates a valid Security::Policy record for the dependency_firewall_policy type and links it
  # to the project so project.security_policies finds it, mirroring the PolicyEvaluator spec helper.
  def create_firewall_policy(name:, rules:, enforcement_type: 'enforced', policy_index: 0)
    policy_config = create(:security_orchestration_policy_configuration, project: project)

    policy = create(:security_policy, :dependency_firewall_policy,
      security_orchestration_policy_configuration: policy_config,
      name: name,
      policy_index: policy_index,
      linked_projects: [project],
      content: {
        name: name,
        enabled: true,
        enforcement_type: enforcement_type,
        rules: rules,
        bypass_settings: { users: [], access_tokens: [] }
      })

    Array.wrap(policy.content&.deep_symbolize_keys&.dig(:rules)).each_with_index do |rule_hash, index|
      create(:dependency_firewall_policy_rule,
        security_policy: policy,
        rule_index: index,
        type: Security::DependencyFirewallPolicyRule.types[rule_hash[:type]],
        content: rule_hash.except(:type))
    end

    policy
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError, /private method [`']new' called/)
    end
  end

  describe '.firewall_check' do
    let(:pkg_type) { 'npm' }
    let(:name) { 'lodash' }
    let(:version) { '4.17.21' }
    let(:operation) { described_class::PACKAGE_DOWNLOAD }

    subject(:firewall_check) do
      described_class.firewall_check(project: project, pkg_type: pkg_type, name: name, version: version,
        operation: operation, current_user: current_user)
    end

    context 'when project is nil' do
      let(:project) { nil }

      before do
        stub_feature_flags(dependency_firewall_phase1: true)
      end

      it 'raises ArgumentError' do
        expect { firewall_check }.to raise_error(ArgumentError, /DependencyFirewall: project is nil/)
      end
    end

    context 'when project is valid', :saas_dependency_firewall do
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(dependency_firewall_phase1: false)
        end

        it 'returns success with allowed status' do
          expect(firewall_check).to be_success
          expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
        end
      end

      context 'when project is not licensed' do
        before do
          stub_feature_flags(dependency_firewall_phase1: true)
          allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
        end

        it 'returns success with allowed status' do
          expect(firewall_check).to be_success
          expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
        end
      end

      context 'when namespace setting is disabled' do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(true)
          namespace_settings = project.root_ancestor.namespace_settings ||
            project.root_ancestor.create_namespace_settings!
          namespace_settings.update!(dependency_firewall_enabled: false)
        end

        it 'returns success with allowed status', :aggregate_failures do
          expect(firewall_check).to be_success
          expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
        end
      end

      context 'when project is licensed', :clean_gitlab_redis_shared_state do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(true)
          namespace_settings = project.root_ancestor.namespace_settings ||
            project.root_ancestor.create_namespace_settings!
          namespace_settings.update!(dependency_firewall_enabled: true)
          allow_next_instance_of(Security::DependencyFirewall::CreateAuditEventsService) do |svc|
            allow(svc).to receive(:execute)
          end
        end

        context 'when pkg_type is blank' do
          where(:pkg_type) { [[''], [nil]] }

          with_them do
            it 'raises ArgumentError' do
              expect { firewall_check }.to raise_error(ArgumentError, /DependencyFirewall: pkg_type is blank/)
            end
          end
        end

        context 'when name is blank' do
          where(:name) { [[''], [nil]] }

          with_them do
            it 'raises ArgumentError' do
              expect { firewall_check }.to raise_error(ArgumentError, /DependencyFirewall: name is blank/)
            end
          end
        end

        context 'when version is nil (e.g. metadata package)' do
          let(:version) { nil }

          it 'allows the check to proceed' do
            expect(firewall_check).to be_success
            expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
          end
        end

        context 'when operation is invalid' do
          where(:operation) { [[999], [nil]] }

          with_them do
            it 'raises ArgumentError' do
              expect { firewall_check }.to raise_error(ArgumentError, /DependencyFirewall: operation/)
            end
          end
        end

        context 'when operation is valid' do
          where(:operation_type) do
            [
              [described_class::PACKAGE_DOWNLOAD],
              [described_class::PACKAGE_UPLOAD],
              [described_class::CONTAINER_PULL],
              [described_class::CONTAINER_PUSH],
              [described_class::PACKAGE_FORWARDED]
            ]
          end

          with_them do
            let(:operation) { operation_type }

            before do
              allow_next_instance_of(Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ name: 'MIT' }])
              end
            end

            it 'returns success with allowed status' do
              expect(firewall_check).to be_success
              expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
            end
          end

          context 'when tracking dependency firewall events' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ name: 'MIT' }])
              end
            end

            context 'when package is allowed (no policy match)' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([])
                end
              end

              it 'tracks event with SUCCESS_ALLOWED outcome' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user,
                  hash_including(
                    outcome: described_class::SUCCESS_ALLOWED,
                    operation: described_class::PACKAGE_DOWNLOAD
                  )
                ).and_return(double)

                firewall_check
              end

              it 'records allowed activity with no rule (NULL rule_id)' do
                expect do
                  firewall_check
                  flush_activity_stats
                end.to change {
                  Security::DependencyFirewallActivityStat
                    .where(project_id: project.id, dependency_firewall_policy_rule_id: nil, outcome: :allowed)
                    .sum(:count)
                }.by(1)
              end

              it 'issues no write to the activity stats table on the enforcement path' do
                recorder = ActiveRecord::QueryRecorder.new { firewall_check }

                writes = recorder.log.select do |sql|
                  sql.include?('dependency_firewall_activity_stats') && sql.match?(/\b(INSERT|UPDATE|DELETE)\b/i)
                end

                expect(writes).to be_empty
              end
            end

            context 'when package is blocked' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([
                    { policy_name: 'Block Policy', action: :denied, reason: :evaluation }
                  ])
                end
              end

              it 'tracks event with SUCCESS_BLOCKED outcome' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user,
                  hash_including(outcome: described_class::SUCCESS_BLOCKED)
                ).and_return(double)

                firewall_check
              end
            end

            context 'when package is warned' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([
                    { policy_name: 'Warn Policy', action: :warned, reason: :evaluation }
                  ])
                end
              end

              it 'tracks event with SUCCESS_WARNING outcome' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user,
                  hash_including(outcome: described_class::SUCCESS_WARNING)
                ).and_return(double)

                firewall_check
              end

              it 'records warned activity' do
                expect do
                  firewall_check
                  flush_activity_stats
                end.to change {
                  Security::DependencyFirewallActivityStat
                    .where(project_id: project.id, outcome: :warned)
                    .sum(:count)
                }.by(1)
              end
            end

            context 'when a matched rule records dashboard activity' do
              let_it_be(:rule) { create(:dependency_firewall_policy_rule) }

              let(:matched_rule) do
                Security::DependencyFirewallPolicies::Rule.new(type: 'license', rule_id: rule.id)
              end

              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([
                    { policy_name: 'Block Policy', action: :denied, reason: :evaluation, matched_rule: matched_rule }
                  ])
                end
              end

              it 'increments the blocked activity counter for the rule and project', :aggregate_failures do
                expect do
                  firewall_check
                  flush_activity_stats
                end.to change {
                  Security::DependencyFirewallActivityStat
                    .where(dependency_firewall_policy_rule_id: rule.id, project_id: project.id)
                    .sum(:count)
                }.by(1)

                expect(
                  Security::DependencyFirewallActivityStat
                    .where(dependency_firewall_policy_rule_id: rule.id, project_id: project.id)
                    .order(:id)
                    .last
                ).to have_attributes(outcome: 'blocked')
              end
            end

            context 'when a real persisted rule drives attribution end-to-end' do
              # Unlike the mocked contexts above, this drives an unmocked PolicyEvaluator against a
              # real persisted policy + rule, exercising the full attribution chain:
              # DependencyFirewallPolicy#rules threads rule_id -> evaluator sets matched_rule ->
              # record_activity persists dependency_firewall_policy_rule_id.
              let_it_be(:policy_config) do
                create(:security_orchestration_policy_configuration, project: project)
              end

              let(:persisted_rule) do
                policy = create(:security_policy, :dependency_firewall_policy,
                  security_orchestration_policy_configuration: policy_config,
                  name: 'e2e-policy',
                  policy_index: 0,
                  linked_projects: [project],
                  content: {
                    name: 'e2e-policy',
                    enabled: true,
                    enforcement_type: 'enforced',
                    rules: [{ type: 'license', denied: [{ name: 'MIT' }] }],
                    bypass_settings: { users: [], access_tokens: [] }
                  })

                create(:dependency_firewall_policy_rule,
                  security_policy: policy,
                  rule_index: 0,
                  type: Security::DependencyFirewallPolicyRule.types[:license],
                  content: { denied: [{ name: 'MIT' }] })
              end

              before do
                persisted_rule
              end

              it 'records blocked activity against the persisted rule id', :aggregate_failures do
                expect do
                  firewall_check
                  flush_activity_stats
                end.to change {
                  Security::DependencyFirewallActivityStat
                    .where(project_id: project.id, outcome: :blocked)
                    .sum(:count)
                }.by(1)

                expect(
                  Security::DependencyFirewallActivityStat
                    .where(project_id: project.id, outcome: :blocked)
                    .order(:id)
                    .last
                ).to have_attributes(dependency_firewall_policy_rule_id: persisted_rule.id)
              end
            end

            context 'when recording activity raises' do
              before do
                allow(Security::DependencyFirewall::CreateEventService).to receive(:new).and_return(
                  instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                )
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([
                    { policy_name: 'Block Policy', action: :denied, reason: :evaluation }
                  ])
                end
                allow(Security::DependencyFirewallActivityStat)
                  .to receive(:increment!).and_raise(StandardError, 'counter unavailable')
              end

              it 'does not break enforcement and reports the error', :aggregate_failures do
                expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                  instance_of(StandardError),
                  hash_including(project_id: project.id, outcome: :blocked)
                )

                result = firewall_check

                expect(result).to be_error
                expect(result.reason).to eq(described_class::SUCCESS_BLOCKED)
              end
            end

            context 'when no licenses are found for the package' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                  allow(svc).to receive(:execute).and_return([])
                end
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([])
                end
              end

              it 'still invokes the evaluator and tracks SUCCESS_ALLOWED when it allows' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user,
                  hash_including(outcome: described_class::SUCCESS_ALLOWED)
                ).and_return(double)

                firewall_check
              end
            end

            context 'with a package operation' do
              it 'includes purl in event params' do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([])
                end

                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user, hash_including(purl: "pkg:npm/lodash@4.17.21")
                ).and_return(double)

                firewall_check
              end
            end

            context 'when tracking the operation' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([])
                end
              end

              context 'when the operation is a package forward' do
                let(:operation) { described_class::PACKAGE_FORWARDED }

                it 'tracks the event with the forwarded operation' do
                  double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                  expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                    project, current_user, hash_including(operation: described_class::PACKAGE_FORWARDED)
                  ).and_return(double)

                  firewall_check
                end
              end

              context 'when the operation is not a package forward' do
                let(:operation) { described_class::PACKAGE_DOWNLOAD }

                it 'tracks the event with the package download operation' do
                  double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                  expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                    project, current_user, hash_including(operation: described_class::PACKAGE_DOWNLOAD)
                  ).and_return(double)

                  firewall_check
                end
              end
            end

            context 'with a container operation' do
              let(:operation) { described_class::CONTAINER_PULL }
              let(:pkg_type) { 'docker' }
              let(:name) { 'cassandra' }
              let(:version) { 'sha256:244fd47e07d1004f0aed9c' }

              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([])
                end
              end

              it 'includes purl in event params' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user,
                  hash_including(purl: "pkg:docker/cassandra@sha256:244fd47e07d1004f0aed9c")
                ).and_return(double)

                firewall_check
              end
            end

            context 'when both denied and warned results are present' do
              before do
                allow_next_instance_of(Security::DependencyFirewall::PolicyEvaluator) do |ev|
                  allow(ev).to receive(:evaluate).and_return([
                    { policy_name: 'Warn Policy', action: :warned, reason: :evaluation },
                    { policy_name: 'Block Policy', action: :denied, reason: :evaluation }
                  ])
                end
              end

              it 'tracks SUCCESS_BLOCKED outcome (denied takes priority over warned)' do
                double = instance_double(Security::DependencyFirewall::CreateEventService, execute: nil)
                expect(Security::DependencyFirewall::CreateEventService).to receive(:new).with(
                  project, current_user, hash_including(outcome: described_class::SUCCESS_BLOCKED)
                ).and_return(double)

                firewall_check
              end
            end

            context 'when feature is disabled (project not licensed)' do
              before do
                allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
              end

              it 'does not track any event' do
                expect(Security::DependencyFirewall::CreateEventService).not_to receive(:new)

                firewall_check
              end
            end
          end

          context 'when the package does not exist in the package metadata database' do
            let(:pkg_type) { 'maven' }
            let(:name) { 'unknown-lib' }
            let(:version) { '1.0.0' }
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            it 'returns allowed when licenses cannot be determined' do
              expect(firewall_check).to be_success
              expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
            end
          end

          context 'when the package exists in the package metadata database' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            where(:pkg_type, :name, :version) do
              [
                ['maven', 'trivial-lib', '1.0.0'],
                ['maven', 'commons-lang3', '3.12.0'],
                ['npm', 'lodash', '4.17.21']
              ]
            end

            with_them do
              before do
                create(:pm_package,
                  name: name,
                  purl_type: pkg_type,
                  other_licenses: [{ license_names: ['Apache-2.0'], versions: [version] }])
              end

              it 'succeeds after fetching license data' do
                expect(firewall_check).to be_success
                expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
              end
            end
          end

          context 'when vulnerabilities are fetched' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }
            let(:fetched_vulnerabilities) do
              [{ id: 'CVE-2099-0001', severity: 'high' }]
            end

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return(fetched_vulnerabilities)
              end
            end

            it 'forwards them to the PolicyEvaluator under :vulnerabilities' do
              expect_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |evaluator|
                expect(evaluator).to receive(:evaluate)
                  .with(name, hash_including(vulnerabilities: fetched_vulnerabilities))
                  .and_return([])
              end

              firewall_check
            end
          end

          context 'when malicious data is fetched' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }
            let(:fetched_malicious) { [{ advisory: { id: 'MAL-0001' } }] }

            before do
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageMaliciousService) do |svc|
                allow(svc).to receive(:execute).and_return(fetched_malicious)
              end
            end

            it 'forwards them to the PolicyEvaluator under :malicious_packages' do
              expect_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |evaluator|
                expect(evaluator).to receive(:evaluate)
                  .with(name, hash_including(malicious_packages: fetched_malicious))
                  .and_return([])
              end

              firewall_check
            end
          end

          context 'with a malicious rule policy' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }
            let(:malicious_rule) { { type: 'malicious', denied: [{ is_malicious: true }] } }

            before do
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageMaliciousService) do |svc|
                allow(svc).to receive(:execute).and_return(fetched_malicious)
              end
            end

            context 'when the package is flagged as malicious under an enforce policy' do
              let(:fetched_malicious) { [{ advisory: { id: 'MAL-0001' } }] }

              before do
                create_firewall_policy(name: 'malicious-policy', rules: [malicious_rule], enforcement_type: 'enforced')
              end

              it 'blocks the package', :aggregate_failures do
                expect(firewall_check).to be_error
                expect(firewall_check.reason).to eq(described_class::SUCCESS_BLOCKED)
              end
            end

            context 'when the package is flagged as malicious under a warn policy' do
              let(:fetched_malicious) { [{ advisory: { id: 'MAL-0001' } }] }

              before do
                create_firewall_policy(name: 'malicious-warn-policy', rules: [malicious_rule], enforcement_type: 'warn')
              end

              it 'warns', :aggregate_failures do
                expect(firewall_check).to be_success
                expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_WARNING)
              end
            end

            context 'when no malicious data flags the package' do
              let(:fetched_malicious) { [] }

              before do
                create_firewall_policy(name: 'malicious-policy', rules: [malicious_rule], enforcement_type: 'enforced')
              end

              it 'allows the package', :aggregate_failures do
                expect(firewall_check).to be_success
                expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
              end
            end
          end

          context 'when both licenses and vulnerabilities are empty' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
            end

            it 'still evaluates the policy and lets the evaluator decide the outcome', :aggregate_failures do
              expect_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |evaluator|
                expect(evaluator).to receive(:evaluate)
                  .with(name, hash_including(licenses: [], vulnerabilities: []))
                  .and_return([])
              end

              expect(firewall_check).to be_success
              expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
            end
          end

          context 'when the policy has only vulnerability rules and license data is empty' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }
            let(:fetched_vulnerabilities) do
              [{ id: 'CVE-2099-0001', severity: 'low' }]
            end

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return(fetched_vulnerabilities)
              end
              allow_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |ev|
                allow(ev).to receive(:evaluate)
                  .and_return([{ policy_name: 'vuln only', action: :allowed, reason: :evaluation }])
              end
            end

            it 'does not block because of the missing license data', :aggregate_failures do
              expect(firewall_check).to be_success
              expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
            end
          end

          context 'when the policy has only license rules and vulnerability data is empty' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ name: 'MIT' }])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return([])
              end
              allow_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |ev|
                allow(ev).to receive(:evaluate)
                  .and_return([{ policy_name: 'license only', action: :allowed, reason: :evaluation }])
              end
            end

            it 'does not block because of the missing vulnerability data', :aggregate_failures do
              expect(firewall_check).to be_success
              expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
            end
          end

          context 'when the policy has both license and vulnerability rules and neither allows' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ name: 'GPL-3.0' }])
              end
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageVulnerabilitiesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ id: 'CVE-2099-0001', severity: 'critical' }])
              end
              allow_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |ev|
                allow(ev).to receive(:evaluate).and_return([
                  { policy_name: 'license rule', action: :denied, reason: :evaluation },
                  { policy_name: 'vulnerability rule', action: :denied, reason: :evaluation }
                ])
              end
            end

            it 'blocks the package', :aggregate_failures do
              expect(firewall_check).to be_error
              expect(firewall_check.reason).to eq(described_class::SUCCESS_BLOCKED)
            end
          end

          context 'when evaluating policy result priority' do
            let(:operation) { described_class::PACKAGE_DOWNLOAD }

            before do
              stub_feature_flags(dependency_firewall_phase1: true)
              allow_next_instance_of(::Security::DependencyFirewall::FetchPackageLicensesService) do |svc|
                allow(svc).to receive(:execute).and_return([{ name: 'MIT' }])
              end
              allow_next_instance_of(::Security::DependencyFirewall::PolicyEvaluator) do |ev|
                allow(ev).to receive(:evaluate).and_return(evaluator_results)
              end
            end

            context 'when results are empty' do
              let(:evaluator_results) { [] }

              it 'returns allowed' do
                expect(firewall_check).to be_success
                expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
              end
            end

            context 'when all results are :allowed' do
              let(:evaluator_results) do
                [
                  { policy_name: 'policy 1', action: :allowed, reason: :evaluation },
                  { policy_name: 'policy 2', action: :allowed, reason: :user_bypassed }
                ]
              end

              it 'returns allowed' do
                expect(firewall_check).to be_success
                expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_ALLOWED)
              end

              it 'audits the bypass/exception result rather than an empty one' do
                audit_service = instance_double(Security::DependencyFirewall::CreateAuditEventsService, execute: nil)

                expect(Security::DependencyFirewall::CreateAuditEventsService).to receive(:new).with(
                  hash_including(
                    event_type: :allowed,
                    result: { policy_name: 'policy 2', action: :allowed, reason: :user_bypassed }
                  )
                ).and_return(audit_service)

                firewall_check
              end
            end

            context 'when all allowed results have a non-notable reason' do
              let(:evaluator_results) do
                [
                  { policy_name: 'policy 1', action: :allowed, reason: :evaluation },
                  { policy_name: 'policy 2', action: :allowed, reason: :no_matches }
                ]
              end

              it 'audits with an empty result' do
                audit_service = instance_double(Security::DependencyFirewall::CreateAuditEventsService, execute: nil)

                expect(Security::DependencyFirewall::CreateAuditEventsService).to receive(:new).with(
                  hash_including(event_type: :allowed, result: {})
                ).and_return(audit_service)

                firewall_check
              end
            end

            context 'when results include :allowed, :warned, and :denied' do
              let(:evaluator_results) do
                [
                  { policy_name: 'policy 1', action: :allowed, reason: :evaluation },
                  { policy_name: 'policy 2', action: :warned, reason: :user_bypassed },
                  { policy_name: 'policy 3', action: :denied, reason: :token_bypassed }
                ]
              end

              it 'returns blocked (denied takes highest priority)' do
                expect(firewall_check).to be_error
                expect(firewall_check.reason).to eq(described_class::SUCCESS_BLOCKED)
                expect(firewall_check.message).to eq("Package 'lodash' violates 'policy 3' policy")
              end
            end

            context 'when multiple results are of the same action, the first policy name is used' do
              context 'with multiple :denied results' do
                let(:evaluator_results) do
                  [
                    { policy_name: 'block policy 1', action: :denied, reason: :evaluation },
                    { policy_name: 'block policy 2', action: :denied, reason: :evaluation }
                  ]
                end

                it 'uses the first denied policy name in the message' do
                  expect(firewall_check).to be_error
                  expect(firewall_check.message).to eq("Package 'lodash' violates 'block policy 1' policy")
                end
              end

              context 'with :allowed and :warned results' do
                let(:evaluator_results) do
                  [
                    { policy_name: 'warn policy 1', action: :allowed, reason: :evaluation },
                    { policy_name: 'warn policy 2', action: :warned, reason: :evaluation }
                  ]
                end

                it 'uses the first warned policy name in the message' do
                  expect(firewall_check).to be_success
                  expect(firewall_check.payload[:status]).to eq(described_class::SUCCESS_WARNING)
                  expect(firewall_check.payload[:message]).to eq("Package 'lodash' violates 'warn policy 2' policy")
                end
              end
            end
          end
        end
      end
    end
  end
end
