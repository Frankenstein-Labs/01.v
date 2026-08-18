# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::SecurityOrchestrationPolicies::LazyComplianceFrameworkAggregate, feature_category: :security_policy_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: current_user) }
  let_it_be_with_reload(:framework) { create(:compliance_framework) }
  let_it_be_with_reload(:other_framework) { create(:compliance_framework) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_reload(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let(:policy_type) { :scan_result_policies }
  let(:query_ctx) { { current_user: current_user } }
  let(:state_key) { lazy_aggregate.state_key }

  subject(:lazy_aggregate) { described_class.new(query_ctx, framework, policy_type) }

  describe '#initialize' do
    it 'adds the frameworks to the lazy state' do
      expect(lazy_aggregate.lazy_state[:pending_frameworks]).to eq [framework]
      expect(lazy_aggregate.object).to eq framework
    end

    context 'when there is pending_framework' do
      let(:result) do
        described_class.new(
          {
            state_key => {
              pending_frameworks: [other_framework],
              loaded_objects: {}
            }
          },
          framework,
          policy_type
        )
      end

      it 'uses the state_key to collect aggregates' do
        expect(result.lazy_state[:pending_frameworks]).to match_array [other_framework, framework]
        expect(result.object).to eq framework
      end
    end
  end

  describe '#execute' do
    let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
    let_it_be(:ref_project) { create(:project) }
    let_it_be(:content) { { project: ref_project.full_path, file: 'pipeline_execution_policy.yml' } }
    let(:scan_execution_policy) do
      build(:scan_execution_policy, name: 'SEP 1', policy_scope: policy_scope)
    end

    let(:approval_policy) do
      build(:approval_policy, name: 'SRP 1', policy_scope: policy_scope)
    end

    let(:pipeline_execution_policy) do
      build(:pipeline_execution_policy, name: 'PEP 1', policy_scope: policy_scope, content: { include: [content] })
    end

    let(:vulnerability_management_policy) do
      build(
        :vulnerability_management_policy,
        name: 'VMP 1', policy_scope: policy_scope, content: { include: [content] })
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml,
        scan_execution_policy: [scan_execution_policy],
        approval_policy: [approval_policy],
        pipeline_execution_policy: [pipeline_execution_policy],
        vulnerability_management_policy: [vulnerability_management_policy]
      )
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
      lazy_aggregate.instance_variable_set(:@lazy_state, fake_state)

      allow(Project).to receive(:find_by_full_path).with(content[:project]).and_return(ref_project)
      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    context 'when the record is already been loaded' do
      let(:fake_state) do
        {
          pending_frameworks: [],
          loaded_objects: {
            framework.id => {
              approval_policies: [],
              scan_execution_policies: [],
              pipeline_execution_policy: [],
              vulnerability_management_policy: []
            }
          }
        }
      end

      it 'does not call the finder' do
        expect(::Security::SecurityPoliciesFinder).not_to receive(:new)

        lazy_aggregate.execute
      end
    end

    context 'when the record is not loaded' do
      let(:fake_state) do
        { pending_frameworks: Set.new([framework, other_framework]), loaded_objects: {} }
      end

      it 'makes the query' do
        policies = lazy_aggregate.execute

        expect(policies.count).to eq(1)
        expect(policies[0][:name]).to eq(approval_policy[:name])
      end

      it 'clears the pending frameworks' do
        lazy_aggregate.execute

        expect(lazy_aggregate.lazy_state[:pending_frameworks]).to be_empty
      end

      context 'when policy is not scoped to the loaded framework' do
        let(:policy_scope) { { compliance_frameworks: [{ id: other_framework.id }] } }

        it 'does not return policies' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(0)
        end
      end

      context 'when policy_scope is empty' do
        let(:policy_scope) { {} }

        it 'does not return policies' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(0)
        end
      end
    end

    describe '#load_queued_records deduplication' do
      let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
      let_it_be(:ref_project) { create(:project) }
      let_it_be(:content) { { project: ref_project.full_path, file: 'pipeline_execution_policy.yml' } }

      let(:duplicate_policy_1) { build(:scan_execution_policy, name: 'Duplicate Policy', policy_scope: policy_scope) }
      let(:duplicate_policy_2) { build(:scan_execution_policy, name: 'Duplicate Policy', policy_scope: policy_scope) }

      let(:policy_yaml_with_duplicates) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [duplicate_policy_1, duplicate_policy_2]
        )
      end

      let(:policy_type) { :scan_execution_policies }
      let(:policy_yaml) { policy_yaml_with_duplicates }
      let(:fake_state) { { pending_frameworks: Set.new([framework]), loaded_objects: {} } }

      before do
        stub_licensed_features(security_orchestration_policies: true)
        lazy_aggregate.instance_variable_set(:@lazy_state, fake_state)

        allow(Project).to receive(:find_by_full_path).with(content[:project]).and_return(ref_project)
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
        end
      end

      context 'when there are duplicate policies' do
        it 'deduplicates policies with same name and management project id' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(1)
          expect(policies.first[:name]).to eq('Duplicate Policy')
        end
      end

      context 'when policies have the same name but from different management projects' do
        let_it_be(:other_project) { create(:project, maintainers: current_user) }
        let_it_be_with_reload(:other_policy_configuration) do
          create(:security_orchestration_policy_configuration, project: other_project)
        end

        let_it_be_with_reload(:other_compliance_framework_security_policy) do
          create(:compliance_framework_security_policy,
            policy_configuration: other_policy_configuration,
            framework: framework)
        end

        let(:policy_yaml_with_same_name) do
          build(:orchestration_policy_yaml,
            scan_execution_policy: [build(:scan_execution_policy, name: 'Same Name Policy', policy_scope: policy_scope)]
          )
        end

        let(:policy_yaml) { policy_yaml_with_same_name }

        it 'does not deduplicate policies from different management projects' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(2)
          expect(policies.pluck(:name)).to match_array(['Same Name Policy', 'Same Name Policy'])
        end
      end
    end
  end
end
