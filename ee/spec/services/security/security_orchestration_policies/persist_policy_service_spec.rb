# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PersistPolicyService, '#execute', feature_category: :security_policy_management do
  let_it_be(:policy_project) { create(:project) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
  end

  def persist!(policies)
    described_class
      .new(policy_configuration: policy_configuration, policies: policies, policy_type: policy_type)
      .execute
  end

  def persist_with_force_resync!
    described_class
      .new(policy_configuration: policy_configuration, policies: policies, policy_type: policy_type, force_resync: true)
      .execute
  end

  shared_examples "persists attributes" do
    before do
      persist
    end

    subject(:persisted_records) { relation }

    specify :aggregate_failures do
      expect(persisted_records.size).to be(expected_attributes.size)

      persisted_records.each_with_index do |persisted_record, index|
        expect(persisted_record).to have_attributes(expected_attributes[index])
      end
    end
  end

  subject(:persist) { persist!(policies) }

  describe "approval policies" do
    let(:policy_type) { :approval_policy }

    let(:scan_finding_policy) do
      build(:approval_policy, :with_approval_settings, :with_policy_scope)
    end

    let(:license_finding_policy) do
      build(:approval_policy, :license_finding, :with_approval_settings)
    end

    let(:any_merge_request_policy) do
      build(:approval_policy, :any_merge_request, :with_policy_scope)
    end

    let(:policies) do
      [scan_finding_policy, license_finding_policy, any_merge_request_policy]
    end

    context 'without pre-existing policies' do
      it 'logs the start of policy persistence' do
        expect(Gitlab::AppJsonLogger).to receive(:debug).with(
          hash_including({
            class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policy_type: policy_type,
            message: 'Starting security policy persistence'
          }.deep_stringify_keys)
        ).ordered

        expect(Gitlab::AppJsonLogger).to receive(:debug).with(
          hash_including({
            class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policy_type: policy_type,
            new_policies_count: 3,
            deleted_policies_count: 0,
            updated_policies_count: 0,
            rearranged_policies_count: 0,
            message: 'security policy persisted'
          }.deep_stringify_keys)
        ).ordered

        persist
      end

      it 'creates policies' do
        expect { persist }.to change { policy_configuration.security_policies.reload.type_approval_policy.count }.by(3)
      end

      it 'calls CollectPoliciesAuditService with created policies' do
        expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with(
          policy_configuration: policy_configuration.reload,
          created_policies: policy_configuration.security_policies.reload.type_approval_policy,
          updated_policies: [],
          deleted_policies: []
        ).and_call_original

        persist
      end

      it 'calls EventPublisher with created policies' do
        expect(Security::SecurityOrchestrationPolicies::EventPublisher).to receive(:new).with({
          db_policies: contain_exactly(
            have_attributes(name: scan_finding_policy[:name]),
            have_attributes(name: license_finding_policy[:name]),
            have_attributes(name: any_merge_request_policy[:name])
          ),
          created_policies: contain_exactly(
            have_attributes(name: scan_finding_policy[:name]),
            have_attributes(name: license_finding_policy[:name]),
            have_attributes(name: any_merge_request_policy[:name])
          ),
          policies_changes: [],
          deleted_policies: [],
          force_resync: false
        }).and_call_original

        persist
      end

      it 'creates policy rules' do
        expect do
          persist
        end.to change { Security::ApprovalPolicyRule.type_scan_finding.count }.by(1)
                 .and change { Security::ApprovalPolicyRule.type_license_finding.count }.by(1)
                        .and change { Security::ApprovalPolicyRule.type_any_merge_request.count }.by(1)
      end

      describe 'rule indexes' do
        subject { Security::ApprovalPolicyRule.type_scan_finding.order(rule_index: :asc).pluck(:rule_index) }

        before do
          scan_finding_policy[:rules] *= 2

          persist
        end

        it { is_expected.to eq([0, 1]) }
      end

      describe 'policy types' do
        subject { Security::ApprovalPolicyRule.pluck(:type) }

        before do
          persist
        end

        it { is_expected.to contain_exactly("scan_finding", "license_finding", "any_merge_request") }
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_approval_policy.order(policy_index: :asc) }

            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: scan_finding_policy[:name],
                  type: 'approval_policy',
                  description: scan_finding_policy[:description],
                  checksum: Security::Policy.checksum(scan_finding_policy),
                  enabled: true,
                  content: scan_finding_policy
                    .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:approval_policy]).deep_stringify_keys,
                  scope: scan_finding_policy[:policy_scope].deep_stringify_keys
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 1,
                  name: license_finding_policy[:name],
                  type: 'approval_policy',
                  description: license_finding_policy[:description],
                  checksum: Security::Policy.checksum(license_finding_policy),
                  enabled: true,
                  content: license_finding_policy
                    .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:approval_policy]).deep_stringify_keys,
                  scope: {}
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 2,
                  name: any_merge_request_policy[:name],
                  type: 'approval_policy',
                  description: any_merge_request_policy[:description],
                  checksum: Security::Policy.checksum(any_merge_request_policy),
                  enabled: true,
                  content: any_merge_request_policy
                    .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:approval_policy]).deep_stringify_keys,
                  scope: any_merge_request_policy[:policy_scope].deep_stringify_keys
                }
              ]
            end
          end
        end

        describe 'rules' do
          include_examples 'persists attributes' do
            let(:relation) { Security::ApprovalPolicyRule.type_scan_finding }
            let(:expected_attributes) do
              [{
                security_policy_id: policy_configuration.security_policies.first.id,
                type: 'scan_finding',
                rule_index: 0,
                content: scan_finding_policy[:rules].first.except(:type).stringify_keys
              }]
            end
          end
        end
      end
    end

    context 'with pre-existing policies' do
      let(:pre_existing_policies) { [scan_finding_policy, license_finding_policy] }

      before do
        persist!(pre_existing_policies)
      end

      context 'without policy changes' do
        let(:policies) { pre_existing_policies }

        it 'does not create or delete policies' do
          expect do
            persist
          end.to not_change { Security::Policy.count }
        end

        it 'does not recreate existing policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and not_change { Security::ApprovalPolicyRule.type_any_merge_request.pluck(:id) }.from([])
        end
      end

      context 'with added policies' do
        let(:policies) { pre_existing_policies << any_merge_request_policy }

        it 'logs the policy changes' do
          expect(Gitlab::AppJsonLogger).to receive(:debug).with(
            hash_including({
              class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
              security_orchestration_policy_configuration_id: policy_configuration.id,
              policy_type: policy_type,
              message: 'Starting security policy persistence'
            }.deep_stringify_keys)
          ).ordered

          expect(Gitlab::AppJsonLogger).to receive(:debug).with(
            hash_including({
              class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
              security_orchestration_policy_configuration_id: policy_configuration.id,
              policy_type: policy_type,
              new_policies_count: 1,
              deleted_policies_count: 0,
              updated_policies_count: 0,
              rearranged_policies_count: 0,
              message: 'security policy persisted'
            }.deep_stringify_keys)
          ).ordered

          persist
        end

        it 'creates policies' do
          expect do
            persist
          end.to change { Security::Policy.count }.by(1)
                   .and change { Security::ApprovalPolicyRule.pluck(:type) }
                          .from(contain_exactly("scan_finding", "license_finding"))
                          .to(contain_exactly("scan_finding", "license_finding", "any_merge_request"))
        end

        it 'creates new policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and change { Security::ApprovalPolicyRule.type_any_merge_request.count }.by(1)
        end
      end

      context 'with removed policies' do
        let(:policies) { pre_existing_policies - [scan_finding_policy] }

        it 'logs the policy changes' do
          expect(Gitlab::AppJsonLogger).to receive(:debug).with(
            hash_including({
              class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
              security_orchestration_policy_configuration_id: policy_configuration.id,
              policy_type: policy_type,
              message: 'Starting security policy persistence'
            }.deep_stringify_keys)
          ).ordered

          expect(Gitlab::AppJsonLogger).to receive(:debug).with(
            hash_including({
              class: 'Security::SecurityOrchestrationPolicies::PersistPolicyService',
              security_orchestration_policy_configuration_id: policy_configuration.id,
              policy_type: policy_type,
              new_policies_count: 0,
              deleted_policies_count: 1,
              updated_policies_count: 0,
              rearranged_policies_count: 1,
              message: 'security policy persisted'
            }.deep_stringify_keys)
          ).ordered

          persist
        end

        it 'calls CollectPoliciesAuditService with deleted policies' do
          expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with({
            policy_configuration: policy_configuration,
            created_policies: [],
            updated_policies: [],
            deleted_policies: [Security::Policy.first]
          }).and_call_original

          persist
        end

        it 'calls EventPublisher with deleted policies' do
          expect(Security::SecurityOrchestrationPolicies::EventPublisher).to receive(:new).with({
            db_policies: contain_exactly(
              have_attributes(name: license_finding_policy[:name])
            ),
            created_policies: [],
            policies_changes: [],
            deleted_policies: [Security::Policy.first],
            force_resync: false
          }).and_call_original

          persist
        end

        context 'with force_resync' do
          it 'calls CollectPoliciesAuditService with deleted policies' do
            expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with({
              policy_configuration: policy_configuration,
              created_policies: [],
              updated_policies: [],
              deleted_policies: [Security::Policy.first]
            }).and_call_original

            persist_with_force_resync!
          end

          it 'calls EventPublisher with force_resync set to true' do
            expect(Security::SecurityOrchestrationPolicies::EventPublisher).to receive(:new).with({
              db_policies: contain_exactly(
                have_attributes(name: license_finding_policy[:name])
              ),
              created_policies: [],
              policies_changes: [],
              deleted_policies: [Security::Policy.first],
              force_resync: true
            }).and_call_original

            persist_with_force_resync!
          end
        end

        it 'sets negative index for deleted policies' do
          expect do
            persist
          end.to change { Security::Policy.pluck(:policy_index) }.from(contain_exactly(0, 1)).to(contain_exactly(0, -2))
                   .and not_change { Security::ApprovalPolicyRule.count }
        end

        context 'when a soft-deleted policy occupies the next deletion index' do
          before do
            create(:security_policy, security_orchestration_policy_configuration: policy_configuration,
              policy_index: -2, enabled: false)
          end

          it 'assigns a negative index that does not collide', :aggregate_failures do
            expect { persist }.not_to raise_error

            expect(policy_configuration.security_policies.pluck(:policy_index)).to contain_exactly(0, -2, -3)
          end
        end
      end

      context 'with updated policy name' do
        let(:policy_before) { build(:approval_policy) }
        let(:policy_after) { build(:approval_policy, name: "#{policy_before[:name]} updated") }

        let(:pre_existing_policies) { [policy_before] }
        let(:policies) { [policy_after] }

        it 'creates new policy and sets negative index for old policy' do
          expect do
            persist
          end.to change { Security::Policy.pluck(:policy_index) }.from(contain_exactly(0)).to(contain_exactly(0, -1))
        end
      end

      context 'with updated policy order' do
        let(:policies) { pre_existing_policies.reverse }

        it 'does not create or delete policies' do
          expect do
            persist
          end.to not_change { Security::Policy.count }.from(2)
                   .and not_change { Security::Policy.pluck(:id).to_set }
        end

        it 'does not recreate existing policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and not_change { Security::ApprovalPolicyRule.type_any_merge_request.pluck(:id) }.from([])
        end

        it 'updates policy indexes' do
          expect do
            persist
          end.to change {
            policy_configuration
              .security_policies
              .order(policy_index: :asc)
              .flat_map(&:approval_policy_rules)
              .flat_map(&:type)
          }
                   .from(%w[scan_finding license_finding])
                   .to(%w[license_finding scan_finding])
        end

        context 'when a soft-deleted policy occupies a temporary negative index' do
          before do
            create(:security_policy, security_orchestration_policy_configuration: policy_configuration,
              policy_index: -1, enabled: false)
          end

          it 'reorders policies without colliding with the soft-deleted policy', :aggregate_failures do
            expect { persist }.not_to raise_error

            expect(policy_configuration.security_policies.undeleted.pluck(:policy_index, :name))
              .to match_array([[0, license_finding_policy[:name]], [1, scan_finding_policy[:name]]])
          end
        end
      end

      context 'when policy rules decrease' do
        let(:default_rule) { { type: 'any_merge_request', branch_type: 'default', commits: 'any' } }
        let(:protected_rule) { { type: 'any_merge_request', branch_type: 'protected', commits: 'any' } }

        let(:policy_before) { build(:approval_policy, rules: [default_rule, protected_rule]) }
        let(:policy_after) { build(:approval_policy, name: policy_before[:name], rules: [protected_rule]) }

        let(:pre_existing_policies) { [policy_before] }
        let(:policies) { [policy_after] }

        it 'sets negative index for dangling policy rules' do
          expect { persist }.to change {
            policy_configuration
              .security_policies.order(policy_index: :asc).flat_map(&:approval_policy_rules).flat_map(&:rule_index)
          }.from(contain_exactly(0, 1)).to(contain_exactly(0, -1))
        end

        it 'calls CollectPoliciesAuditService with updated policies' do
          expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with({
            policy_configuration: policy_configuration,
            created_policies: [],
            updated_policies: [Security::Policy.first],
            deleted_policies: []
          }).and_call_original

          persist
        end

        it 'calls EventPublisher with deleted policies' do
          expect(Security::SecurityOrchestrationPolicies::EventPublisher).to receive(:new).with({
            db_policies: contain_exactly(
              have_attributes(name: policy_before[:name])
            ),
            created_policies: [],
            policies_changes: [an_instance_of(Security::SecurityOrchestrationPolicies::PolicyComparer)],
            deleted_policies: [],
            force_resync: false
          }).and_call_original

          persist
        end

        context 'with force_resync' do
          it 'calls CollectPoliciesAuditService with updated policies' do
            expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with({
              policy_configuration: policy_configuration,
              created_policies: [],
              updated_policies: [Security::Policy.first],
              deleted_policies: []
            }).and_call_original

            persist_with_force_resync!
          end

          it 'calls EventPublisher with force_resync set to true' do
            expect(Security::SecurityOrchestrationPolicies::EventPublisher).to receive(:new).with({
              db_policies: contain_exactly(
                have_attributes(name: policy_before[:name])
              ),
              created_policies: [],
              policies_changes: [an_instance_of(Security::SecurityOrchestrationPolicies::PolicyComparer)],
              deleted_policies: [],
              force_resync: true
            }).and_call_original

            persist_with_force_resync!
          end
        end
      end
    end

    context 'with repeated add and remove rounds' do
      let(:policies) { [scan_finding_policy] }

      it 'never reuses the policy_index of a soft-deleted policy', :aggregate_failures do
        persist

        expect do
          3.times do
            persist!([scan_finding_policy, any_merge_request_policy])
            persist!([scan_finding_policy])
          end
        end.not_to raise_error

        expect(policy_configuration.security_policies.pluck(:policy_index)).to contain_exactly(0, -2, -3, -4)
      end
    end
  end

  describe "scan execution policies" do
    let(:policy_type) { :scan_execution_policy }

    let(:pipeline_policy) do
      build(:scan_execution_policy, :with_policy_scope)
    end

    let(:schedule_policy) do
      build(:scan_execution_policy, :with_schedule, :with_policy_scope)
    end

    let(:policies) do
      [pipeline_policy, schedule_policy]
    end

    context 'without pre-existing policies' do
      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_scan_execution_policy.count
        }.by(2)
      end

      it 'creates policy rules' do
        expect do
          persist
        end.to change { Security::ScanExecutionPolicyRule.type_pipeline.count }.by(1)
                 .and change { Security::ScanExecutionPolicyRule.type_schedule.count }.by(1)
      end

      describe 'rule indexes' do
        subject { Security::ScanExecutionPolicyRule.type_pipeline.order(rule_index: :asc).pluck(:rule_index) }

        before do
          pipeline_policy[:rules] *= 2

          persist
        end

        it { is_expected.to eq([0, 1]) }
      end

      describe 'policy types' do
        subject { Security::ScanExecutionPolicyRule.pluck(:type) }

        before do
          persist
        end

        it { is_expected.to contain_exactly("pipeline", "schedule") }
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_scan_execution_policy.order(policy_index: :asc) }
            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: pipeline_policy[:name],
                  type: 'scan_execution_policy',
                  description: pipeline_policy[:description],
                  checksum: Security::Policy.checksum(pipeline_policy),
                  enabled: true,
                  scope: pipeline_policy[:policy_scope].deep_stringify_keys,
                  content: { actions: pipeline_policy[:actions] }.deep_stringify_keys
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 1,
                  name: schedule_policy[:name],
                  type: 'scan_execution_policy',
                  description: schedule_policy[:description],
                  checksum: Security::Policy.checksum(schedule_policy),
                  enabled: true,
                  scope: schedule_policy[:policy_scope].deep_stringify_keys,
                  content: { actions: schedule_policy[:actions] }.deep_stringify_keys
                }
              ]
            end
          end
        end

        describe 'rules' do
          include_examples 'persists attributes' do
            let(:relation) { Security::ScanExecutionPolicyRule.type_pipeline }

            let(:expected_attributes) do
              [{
                security_policy_id: policy_configuration.security_policies.first.id,
                type: 'pipeline',
                rule_index: 0,
                content: pipeline_policy[:rules].first.except(:type).stringify_keys
              }]
            end
          end
        end
      end
    end
  end

  describe "pipeline execution policies" do
    let(:policy_type) { :pipeline_execution_policy }

    let(:pipeline_execution_policy) do
      build(:pipeline_execution_policy, :with_policy_scope)
    end

    let(:policies) do
      [pipeline_execution_policy]
    end

    context 'without pre-existing policies' do
      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_pipeline_execution_policy.count
        }.by(1)
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_pipeline_execution_policy.order(policy_index: :asc) }
            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: pipeline_execution_policy[:name],
                  type: 'pipeline_execution_policy',
                  description: pipeline_execution_policy[:description],
                  checksum: Security::Policy.checksum(pipeline_execution_policy),
                  enabled: true,
                  scope: pipeline_execution_policy[:policy_scope].deep_stringify_keys,
                  content: pipeline_execution_policy.slice(:content, :pipeline_config_strategy, :skip_ci, :no_pipeline,
                    :suffix).deep_stringify_keys
                }
              ]
            end
          end
        end
      end
    end
  end

  describe "pipeline execution schedule policies" do
    let(:policy_type) { :pipeline_execution_schedule_policy }

    let(:pipeline_execution_schedule_policy) do
      build(:pipeline_execution_schedule_policy, :with_policy_scope)
    end

    let(:policies) do
      [pipeline_execution_schedule_policy]
    end

    context 'without pre-existing policies' do
      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_pipeline_execution_schedule_policy.count
        }.by(1)
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_pipeline_execution_schedule_policy.order(policy_index: :asc) }
            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: pipeline_execution_schedule_policy[:name],
                  type: 'pipeline_execution_schedule_policy',
                  description: pipeline_execution_schedule_policy[:description],
                  checksum: Security::Policy.checksum(pipeline_execution_schedule_policy),
                  enabled: true,
                  content: pipeline_execution_schedule_policy.slice(:content, :schedules).deep_stringify_keys
                }
              ]
            end
          end
        end
      end
    end
  end

  describe "vulnerability management policies" do
    let(:policy_type) { :vulnerability_management_policy }

    let(:auto_resolve_policy) { build(:vulnerability_management_policy, :auto_resolve, :with_policy_scope) }
    let(:auto_dismiss_policy) { build(:vulnerability_management_policy, :auto_dismiss, :with_policy_scope) }

    let(:policies) do
      [auto_resolve_policy, auto_dismiss_policy]
    end

    context 'without pre-existing policies' do
      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_vulnerability_management_policy.count
        }.by(2)
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        include_examples 'persists attributes' do
          let(:relation) { Security::Policy.type_vulnerability_management_policy.order(policy_index: :asc) }
          let(:expected_attributes) do
            [
              {
                security_orchestration_policy_configuration_id: policy_configuration.id,
                policy_index: 0,
                name: auto_resolve_policy[:name],
                type: 'vulnerability_management_policy',
                description: auto_resolve_policy[:description],
                checksum: Security::Policy.checksum(auto_resolve_policy),
                enabled: true,
                scope: auto_resolve_policy[:policy_scope].deep_stringify_keys,
                content: auto_resolve_policy.slice(:actions).deep_stringify_keys
              },
              {
                security_orchestration_policy_configuration_id: policy_configuration.id,
                policy_index: 1,
                name: auto_dismiss_policy[:name],
                type: 'vulnerability_management_policy',
                description: auto_dismiss_policy[:description],
                checksum: Security::Policy.checksum(auto_dismiss_policy),
                enabled: true,
                scope: auto_dismiss_policy[:policy_scope].deep_stringify_keys,
                content: auto_dismiss_policy.slice(:actions).deep_stringify_keys
              }
            ]
          end
        end
      end
    end
  end

  describe "dependency firewall policies" do
    let(:policy_type) { :dependency_firewall_policy }

    let(:dependency_firewall_policy) do
      build(:dependency_firewall_policy)
    end

    let(:policies) do
      [dependency_firewall_policy]
    end

    context 'without pre-existing policies' do
      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_dependency_firewall_policy.count
        }.by(1)
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'throws the error' do
          expect { persist }.to raise_error(StandardError, msg)
        end
      end

      describe 'persisted attributes' do
        include_examples 'persists attributes' do
          let(:relation) { Security::Policy.type_dependency_firewall_policy.order(policy_index: :asc) }
          let(:expected_attributes) do
            [
              {
                security_orchestration_policy_configuration_id: policy_configuration.id,
                policy_index: 0,
                name: dependency_firewall_policy[:name],
                type: 'dependency_firewall_policy',
                description: dependency_firewall_policy[:description],
                checksum: Security::Policy.checksum(dependency_firewall_policy),
                enabled: true,
                content: dependency_firewall_policy
                            .slice(:bypass_settings, :enabled, :enforcement_type, :name, :rules)
                            .deep_stringify_keys
              }
            ]
          end
        end
      end
    end
  end

  describe "successive calls with differing policy types" do
    let(:approval_policy) { build(:approval_policy) }
    let(:scan_execution_policy) { build(:scan_execution_policy) }

    subject(:execute) do
      described_class
        .new(policy_configuration: policy_configuration,
          policies: [approval_policy],
          policy_type: :approval_policy)
        .execute

      described_class
        .new(policy_configuration: policy_configuration,
          policies: [scan_execution_policy],
          policy_type: :scan_execution_policy)
        .execute
    end

    specify do
      expect { execute }.to change { policy_configuration.security_policies.count }.by(2)
    end
  end

  describe "collect policy audit events" do
    context "when policy project is linked to multiple projects" do
      let_it_be(:another_policy_configuration) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
      end

      let(:approval_policy) { build(:approval_policy) }
      let(:scan_execution_policy) { build(:scan_execution_policy) }

      subject(:execute) do
        described_class
          .new(policy_configuration: policy_configuration,
            policies: [approval_policy],
            policy_type: :approval_policy)
          .execute

        described_class
          .new(policy_configuration: another_policy_configuration,
            policies: [scan_execution_policy],
            policy_type: :scan_execution_policy)
          .execute
      end

      it 'calls CollectPoliciesAuditService for the first policy configuration only' do
        expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with(
          anything).and_call_original.once

        execute
      end

      it 'calls CollectPoliciesAuditService with correct attributes' do
        expect(Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents).to receive(:new).with({
          policy_configuration: policy_configuration,
          created_policies: policy_configuration.security_policies.reload.type_approval_policy,
          updated_policies: [],
          deleted_policies: []
        }).and_call_original

        execute
      end
    end
  end

  describe 'tracking approval policy feature usage', :clean_gitlab_redis_shared_state do
    let(:policy_type) { :approval_policy }
    let(:project) { policy_configuration.project }
    let(:namespace) { policy_configuration.namespace }

    let(:service) do
      described_class.new(
        policy_configuration: policy_configuration,
        policies: policies,
        policy_type: policy_type
      )
    end

    subject(:execute) { service.execute }

    shared_examples 'does not track any feature usage events' do
      it 'does not track any events' do
        expect { execute }.to not_trigger_internal_events(
          'approval_policy_with_enrichment_filters',
          'approval_policy_with_atomic_scanner_rule'
        )
      end
    end

    context 'when creating a policy with kev_or_epss filters' do
      let(:policies) do
        [build(:approval_policy, vulnerability_attributes: { epss_score: { operator: 'greater_than', value: 0.5 } })]
      end

      it 'tracks the create event for kev_or_epss and increments the related metrics' do
        expect { execute }
          .to trigger_internal_events('approval_policy_with_enrichment_filters')
          .with(project: project, namespace: namespace, additional_properties: { label: 'create' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_enrichment_filters_monthly',
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_enrichment_filters_weekly',
            'counts.count_total_approval_policy_with_enrichment_filters'
          )
      end
    end

    context 'when creating a policy with atomic scanner rules' do
      let(:policies) do
        [build(:approval_policy, rules: [{
          type: 'scan_finding',
          branches: ['master'],
          scanners: [{ type: 'sast', vulnerability_attributes: { fix_available: true } }],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }])]
      end

      it 'tracks the create event for atomic_scanner_rule and increments the related metrics' do
        expect { execute }
          .to trigger_internal_events('approval_policy_with_atomic_scanner_rule')
          .with(project: project, namespace: namespace, additional_properties: { label: 'create' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_atomic_scanner_rule_monthly',
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_atomic_scanner_rule_weekly',
            'counts.count_total_approval_policy_with_atomic_scanner_rule'
          )
      end
    end

    context 'when updating a policy with kev_or_epss filters' do
      let(:policy_name) { 'kev-or-epss-policy' }
      let(:policies) do
        [build(:approval_policy, name: policy_name, vulnerability_attributes: { known_exploited: false })]
      end

      before do
        create(:security_policy, :approval_policy, name: policy_name,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'tracks the update event for kev_or_epss and increments the related metrics' do
        expect { execute }
          .to trigger_internal_events('approval_policy_with_enrichment_filters')
          .with(project: project, namespace: namespace, additional_properties: { label: 'update' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_update_approval_policy_with_enrichment_filters_monthly',
            'redis_hll_counters.count_distinct_project_id_from_update_approval_policy_with_enrichment_filters_weekly',
            'counts.count_total_approval_policy_with_enrichment_filters'
          )
      end
    end

    context 'when updating a policy with atomic scanner rules' do
      let(:policy_name) { 'atomic-policy' }
      let(:policies) do
        [build(:approval_policy, name: policy_name, rules: [{
          type: 'scan_finding',
          branches: ['master'],
          scanners: [{ type: 'sast', vulnerability_attributes: { fix_available: true } }],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }])]
      end

      before do
        create(:security_policy, :approval_policy, name: policy_name,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'tracks the update event for atomic_scanner_rule and increments the related metrics' do
        expect { execute }
          .to trigger_internal_events('approval_policy_with_atomic_scanner_rule')
          .with(project: project, namespace: namespace, additional_properties: { label: 'update' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_update_approval_policy_with_atomic_scanner_rule_monthly',
            'redis_hll_counters.count_distinct_project_id_from_update_approval_policy_with_atomic_scanner_rule_weekly',
            'counts.count_total_approval_policy_with_atomic_scanner_rule'
          )
      end
    end

    context 'when creating a policy with both enrichment filters and atomic scanner rules' do
      let(:policies) do
        [build(:approval_policy,
          rules: [{
            type: 'scan_finding',
            branches: ['master'],
            scanners: [{ type: 'sast', vulnerability_attributes: { fix_available: true } }],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected],
            vulnerability_attributes: { known_exploited: true }
          }]
        )]
      end

      it 'tracks both the kev_or_epss and atomic_scanner_rule create events and increments all related metrics' do
        expect { execute }
          .to trigger_internal_events('approval_policy_with_enrichment_filters')
          .with(project: project, namespace: namespace, additional_properties: { label: 'create' })
          .and trigger_internal_events('approval_policy_with_atomic_scanner_rule')
          .with(project: project, namespace: namespace, additional_properties: { label: 'create' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_enrichment_filters_monthly',
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_enrichment_filters_weekly',
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_atomic_scanner_rule_monthly',
            'redis_hll_counters.count_distinct_project_id_from_create_approval_policy_with_atomic_scanner_rule_weekly',
            'counts.count_total_approval_policy_with_enrichment_filters',
            'counts.count_total_approval_policy_with_atomic_scanner_rule'
          )
      end
    end

    context 'when the policy has no enrichment filters or atomic scanner rules' do
      let(:policies) { [build(:approval_policy)] }

      include_examples 'does not track any feature usage events'
    end

    context 'when policy_type is not approval_policy' do
      let(:policy_type) { :scan_execution_policy }
      let(:policies) { [build(:scan_execution_policy)] }

      include_examples 'does not track any feature usage events'
    end

    context 'when policies list is empty' do
      let(:policies) { [] }

      include_examples 'does not track any feature usage events'
    end
  end

  context "with unrecognized policy type" do
    let(:policies) { [] }
    let(:policy_type) { :foobar }

    it 'errors' do
      expect { persist }.to raise_error(ArgumentError, "unrecognized policy_type")
    end
  end
end
