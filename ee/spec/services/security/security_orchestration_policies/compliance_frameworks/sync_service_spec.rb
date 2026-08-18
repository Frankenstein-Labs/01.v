# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ComplianceFrameworks::SyncService, '#execute', feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
  end

  let_it_be(:framework1) { create(:compliance_framework, namespace: namespace, name: 'GDPR') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'SOX') }

  let_it_be_with_reload(:security_policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:policy_diff) { nil }

  subject(:execute) { described_class.new(security_policy: security_policy, policy_diff: policy_diff).execute }

  before do
    allow(security_policy).to receive(:framework_ids_from_scope)
      .and_return(framework_ids)
  end

  shared_examples 'does not create ComplianceFramework::SecurityPolicy' do
    it { expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::SecurityPolicy.count } }
  end

  shared_examples 'creates ComplianceFramework::SecurityPolicy' do
    let!(:existing_records) do
      [
        create(:compliance_framework_security_policy,
          security_policy: security_policy,
          policy_configuration: policy_configuration,
          framework: create(:compliance_framework, namespace: namespace, name: 'GDPR 2')
        ),
        create(:compliance_framework_security_policy,
          security_policy: security_policy,
          policy_configuration: policy_configuration,
          framework: create(:compliance_framework, namespace: namespace, name: 'SOX 2')
        )
      ]
    end

    it 'creates ComplianceFramework::SecurityPolicy' do
      expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::SecurityPolicy.count }

      # Verify old records are deleted
      expect(
        ComplianceManagement::ComplianceFramework::SecurityPolicy.where(id: existing_records.map(&:id))
      ).to be_empty

      # Verify new records are created
      all_records = ComplianceManagement::ComplianceFramework::SecurityPolicy.all
      expect(all_records.count).to eq(2)
      expect(all_records.map(&:framework_id)).to contain_exactly(framework1.id, framework2.id)
    end
  end

  context 'when no compliance frameworks are linked' do
    let_it_be(:framework_ids) { [] }

    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'
  end

  context 'when policy configuration is scoped to a project' do
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:framework_ids) { [framework1.id, framework2.id] }

    it_behaves_like 'creates ComplianceFramework::SecurityPolicy'
  end

  context 'when inaccessible compliance framework is linked to policy' do
    let_it_be(:inaccessible_framework) { create(:compliance_framework) }
    let_it_be(:framework_ids) { [inaccessible_framework.id] }

    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'

    it 'logs details' do
      expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
        message: 'inaccessible compliance_framework_ids found in policy',
        security_policy_id: security_policy.id,
        configuration_id: policy_configuration.id,
        configuration_source_id: policy_configuration.source.id,
        root_namespace_ids: [namespace.id],
        csp_namespace_id: nil,
        policy_framework_ids: [inaccessible_framework.id],
        inaccessible_framework_ids_count: 1
      ).and_call_original

      execute
    end
  end

  context 'when non existing compliance framework is linked to policy' do
    let_it_be(:framework_ids) { [non_existing_record_id] }

    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'

    it 'logs details' do
      expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
        message: 'inaccessible compliance_framework_ids found in policy',
        security_policy_id: security_policy.id,
        configuration_id: policy_configuration.id,
        configuration_source_id: policy_configuration.source.id,
        root_namespace_ids: [namespace.id],
        csp_namespace_id: nil,
        policy_framework_ids: [non_existing_record_id],
        inaccessible_framework_ids_count: 1
      ).and_call_original

      execute
    end
  end

  context 'when policy scope has changed' do
    let_it_be(:framework_ids) { [framework1.id, framework2.id] }
    let_it_be(:policy_diff) do
      Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.new.tap do |diff|
        diff.add_policy_field(:policy_scope, nil, { projects: { excluding: [{ id: non_existing_record_id }] } })
      end
    end

    it_behaves_like 'creates ComplianceFramework::SecurityPolicy'
  end

  context 'when policy configuration is scoped to a project in a subgroup' do
    let_it_be(:subgroup) { create(:group, parent: namespace) }
    let_it_be(:project_in_subgroup) { create(:project, namespace: subgroup) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project_in_subgroup)
    end

    let_it_be(:framework_ids) { [framework1.id, framework2.id] }

    it_behaves_like 'creates ComplianceFramework::SecurityPolicy'

    context 'when framework belongs to an unrelated root group' do
      let_it_be(:other_root) { create(:group) }
      let_it_be(:other_framework) { create(:compliance_framework, namespace: other_root, name: 'Other FW') }
      let_it_be(:framework_ids) { [other_framework.id] }

      it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'
    end
  end

  context 'when multiple compliance frameworks from different groups are linked to different policies' do
    let_it_be(:namespace2) { create(:group) }
    let_it_be(:policy_configuration2) do
      create(:security_orchestration_policy_configuration,
        namespace: namespace2,
        project: nil,
        security_policy_management_project: policy_configuration.security_policy_management_project)
    end

    let_it_be(:framework3) { create(:compliance_framework, namespace: namespace2, name: 'SOX2') }

    let_it_be(:framework_ids) { [framework1.id, framework2.id, framework3.id] }

    it 'creates ComplianceFramework::SecurityPolicy' do
      execute

      all_records = ComplianceManagement::ComplianceFramework::SecurityPolicy.all
      expect(all_records.count).to eq(3)
      expect(all_records.map(&:policy_configuration_id)).to contain_exactly(
        policy_configuration.id, policy_configuration.id, policy_configuration.id
      )
      expect(all_records.map(&:framework_id)).to contain_exactly(framework1.id, framework2.id, framework3.id)
    end

    context 'when frameworks are linked to different policy configurations' do
      let_it_be(:namespace3) { create(:group) }
      let_it_be(:other_policy_project) { create(:project) }
      let_it_be(:policy_configuration3) do
        create(:security_orchestration_policy_configuration,
          namespace: namespace3,
          project: nil,
          security_policy_management_project: other_policy_project)
      end

      let_it_be(:framework4) { create(:compliance_framework, namespace: namespace3, name: 'HIPAA') }
      let_it_be(:framework_ids) { [framework1.id, framework2.id, framework4.id] }

      it 'logs details about inaccessible frameworks' do
        expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
          hash_including(
            message: 'inaccessible compliance_framework_ids found in policy',
            security_policy_id: security_policy.id,
            configuration_id: policy_configuration.id,
            configuration_source_id: policy_configuration.source.id,
            root_namespace_ids: contain_exactly(namespace.id, namespace2.id),
            csp_namespace_id: nil,
            policy_framework_ids: [framework1.id, framework2.id, framework4.id],
            inaccessible_framework_ids_count: 1
          )
        ).and_call_original

        execute
      end

      it 'does not create ComplianceFramework::SecurityPolicy' do
        expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::SecurityPolicy.count }
      end
    end

    context 'with CSP namespace functionality' do
      include Security::PolicyCspHelpers

      let_it_be(:csp_group) { create(:group) }
      let_it_be(:csp_framework) { create(:compliance_framework, namespace: csp_group, name: 'CSP Framework') }

      before do
        stub_csp_group(csp_group)
      end

      context 'when frameworks exist in both regular and CSP namespaces' do
        let_it_be(:mixed_framework_ids) { [framework1.id, csp_framework.id] }

        before do
          allow(security_policy).to receive(:framework_ids_from_scope).and_return(mixed_framework_ids)
        end

        subject(:execute) { described_class.new(security_policy: security_policy, policy_diff: policy_diff).execute }

        it 'creates records for both regular and CSP frameworks' do
          expect { execute }.to change {
            ComplianceManagement::ComplianceFramework::SecurityPolicy.all.pluck(:framework_id)
          }.from(be_empty).to(contain_exactly(framework1.id, csp_framework.id))
        end
      end

      context 'when only a CSP framework is linked' do
        before do
          allow(security_policy).to receive(:framework_ids_from_scope).and_return([csp_framework.id])
        end

        subject(:execute) { described_class.new(security_policy: security_policy, policy_diff: policy_diff).execute }

        it 'creates a record for the CSP framework' do
          expect { execute }.to change {
            ComplianceManagement::ComplianceFramework::SecurityPolicy.all.pluck(:framework_id)
          }.from(be_empty).to(contain_exactly(csp_framework.id))
        end
      end
    end
  end

  context 'when many configurations are linked to the same management project' do
    let_it_be(:framework_ids) { [framework1.id, framework2.id] }

    it 'does not issue queries proportional to the number of linked configurations' do
      management_project = policy_configuration.security_policy_management_project

      control = ActiveRecord::QueryRecorder.new do
        described_class.new(security_policy: security_policy, policy_diff: policy_diff).execute
      end

      5.times do
        sub = create(:group, parent: namespace)
        create(:security_orchestration_policy_configuration,
          namespace: sub, project: nil,
          security_policy_management_project: management_project)
      end

      expect do
        described_class.new(security_policy: security_policy, policy_diff: policy_diff).execute
      end.not_to exceed_query_limit(control)
    end
  end
end
