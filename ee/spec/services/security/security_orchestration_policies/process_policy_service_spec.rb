# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProcessPolicyService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let(:type) { :scan_execution_policy }
    let(:policy) { build(type, name: 'Test Policy', enabled: false) }
    let(:other_policy) { build(type, name: 'Other Policy') }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(policy.to_yaml).load! }
    let(:policy_name) { policy[:name] }

    let(:repository_with_existing_policy_yaml) do
      pipeline_policy = build(type, name: 'Test Policy')
      build(:orchestration_policy_yaml, type => [pipeline_policy])
    end

    let(:repository_policy_yaml) do
      pipeline_policy = build(type, name: "Execute DAST in every pipeline")
      build(:orchestration_policy_yaml, type => [pipeline_policy])
    end

    let(:policies_yaml) { "{}" }

    subject(:service) do
      described_class.new(
        policy_configuration: policy_configuration,
        params: { policy: policy_yaml, name: policy_name, operation: operation, type: type }
      )
    end

    before do
      allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(policies_yaml).load!)
      stub_feature_flags(dependency_firewall_phase1: true)
    end

    context 'when policy is invalid' do
      let(:policy_name) { 'invalid' }
      let(:policy) { { name: 'invalid', invalid_field: 'invalid' } }
      let(:operation) { :append }

      it 'returns error' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Invalid policy YAML')
        expect(result[:details]).to eq(["property '/scan_execution_policy/0' is missing required keys: enabled, rules, actions"])
      end
    end

    context 'when policy name is not same as in policy' do
      let(:policy_name) { 'invalid' }
      let(:operation) { :append }

      it 'returns error' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Name should be same as the policy name')
      end
    end

    context 'append policy' do
      let(:operation) { :append }

      Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES.each do |policy_type|
        context "when type is #{policy_type}" do
          let(:type) { policy_type }

          context 'when policy is present in repository' do
            let(:policies_yaml) { repository_policy_yaml }

            it 'appends the new policy' do
              result = service.execute

              expect(result[:status]).to eq(:success)
              expect(result.dig(:policy_hash, type).count).to eq(2)
            end
          end

          context 'when policy with same name already exists in repository' do
            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'returns error' do
              result = service.execute

              expect(result[:status]).to eq(:error)
              expect(result[:message]).to eq('Policy already exists with same name')
            end
          end

          context 'when policy is not present in repository' do
            let(:policies_yaml) { "{}" }

            it 'appends the new policy' do
              result = service.execute

              expect(result[:status]).to eq(:success)
              expect(result.dig(:policy_hash, type).count).to eq(1)
            end
          end
        end
      end
    end

    context 'replace policy' do
      let(:operation) { :replace }

      Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES.each do |policy_type|
        context "when type is #{policy_type}" do
          let(:type) { policy_type }

          context 'when policy is not present in repository' do
            let(:policies_yaml) { repository_policy_yaml }

            it 'returns error' do
              result = service.execute

              expect(result[:status]).to eq(:error)
              expect(result[:message]).to eq('Policy does not exist')
            end
          end

          context 'when policy name is empty' do
            let(:policy_name) { nil }
            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'does not modify the policy name' do
              result = service.execute

              expect(result.dig(:policy_hash, type).first).to eq(policy_yaml)
            end
          end

          context 'when policy with same name already exists in repository' do
            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'replaces the policy' do
              result = service.execute

              expect(result.dig(:policy_hash, type).first[:enabled]).to be_falsey
            end
          end

          context 'when policy name is not same as in policy' do
            let(:policy_yaml) do
              Gitlab::Config::Loader::Yaml.new(build(type, name: 'Updated Policy', enabled: false).to_yaml).load!
            end

            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'updates the policy name' do
              result = service.execute

              expect(result.dig(:policy_hash, type).first[:name]).to eq('Updated Policy')
            end
          end

          context 'when name of the policy to be updated already exists' do
            let(:repository_with_existing_policy_yaml) do
              pipeline_policy = build(type, name: 'Test Policy')
              build(:orchestration_policy_yaml, type => [pipeline_policy, other_policy])
            end

            let(:policy_yaml) do
              Gitlab::Config::Loader::Yaml.new(build(type, name: 'Other Policy', enabled: false).to_yaml).load!
            end

            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'returns error' do
              result = service.execute

              expect(result[:status]).to eq(:error)
              expect(result[:message]).to eq('Policy already exists with same name')
            end
          end
        end
      end
    end

    context 'remove policy' do
      let(:operation) { :remove }

      Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES.each do |policy_type|
        context "when type is #{policy_type}" do
          let(:type) { policy_type }

          context 'when policy is not present in repository' do
            let(:policies_yaml) { repository_policy_yaml }

            it 'returns error' do
              result = service.execute

              expect(result[:status]).to eq(:error)
              expect(result[:message]).to eq('Policy does not exist')
            end
          end

          context 'when policy with same name already exists in repository' do
            let(:policies_yaml) { repository_with_existing_policy_yaml }

            it 'removes the policy' do
              result = service.execute

              expect(result[:status]).to eq(:success)
              expect(result.dig(:policy_hash, type).count).to eq(0)
            end
          end
        end
      end
    end
  end
end
