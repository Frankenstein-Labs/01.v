# frozen_string_literal: true

RSpec.shared_examples 'an orchestration policy type' do |policy_trait|
  include GraphqlHelpers

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'field scopes' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name, :scopes) do
      'id'                    | %i[api read_api ai_workflows]
      'policyConfigurationId' | %i[api read_api]
      'description'           | %i[api read_api]
      'editPath'              | %i[api read_api]
      'enabled'               | %i[api read_api ai_workflows]
      'name'                  | %i[api read_api ai_workflows]
      'updatedAt'             | %i[api read_api]
      'yaml'                  | %i[api read_api ai_workflows]
      'policyScope'           | %i[api read_api]
      'csp'                   | %i[api read_api]
    end

    with_them do
      let(:field) { described_class.fields[field_name] }

      subject { field.scopes }

      it { is_expected.to match_array(scopes) }
    end
  end

  describe '#updated_at' do
    let(:policy_last_updated_at) { Time.current }

    context 'when security policy record exists' do
      let_it_be(:security_policy, freeze: false) { create(:security_policy, policy_trait) }
      let(:config) { security_policy.security_orchestration_policy_configuration }
      let(:policy_object) do
        { config: config, type: security_policy.type, policy_index: security_policy.policy_index }
      end

      it 'returns the DB record updated_at' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to be_a(GraphQL::Execution::Lazy)
        expect(result.value).to be_like_time(security_policy.updated_at)
      end
    end

    context 'when security policy record exists but updated_at is nil' do
      let_it_be(:security_policy, freeze: false) { create(:security_policy, policy_trait) }
      let(:config) { security_policy.security_orchestration_policy_configuration }
      let(:policy_object) do
        { config: config, type: security_policy.type, policy_index: security_policy.policy_index }
      end

      before do
        allow(security_policy).to receive(:updated_at).and_return(nil)
        allow(Security::Policy).to receive_message_chain(:for_policy_configuration_ids, :undeleted, :find_each)
          .and_yield(security_policy)
        allow(config).to receive(:policy_last_updated_at).and_return(policy_last_updated_at)
      end

      it 'falls back to config policy_last_updated_at' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to be_a(GraphQL::Execution::Lazy)
        expect(result.value).to eq(policy_last_updated_at)
      end
    end

    context 'when policy_index is nil' do
      let_it_be(:config, freeze: false) { create(:security_orchestration_policy_configuration) }
      let(:policy_object) { { config: config, type: policy_trait.to_s, policy_index: nil } }

      before do
        allow(config).to receive(:policy_last_updated_at).and_return(policy_last_updated_at)
      end

      it 'falls back to config policy_last_updated_at' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to eq(policy_last_updated_at)
      end
    end

    context 'when security policy record does not exist' do
      let_it_be(:config, freeze: false) { create(:security_orchestration_policy_configuration) }
      let(:policy_object) { { config: config, type: policy_trait.to_s, policy_index: 0 } }

      before do
        allow(config).to receive(:policy_last_updated_at).and_return(policy_last_updated_at)
      end

      it 'falls back to config policy_last_updated_at' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to be_a(GraphQL::Execution::Lazy)
        expect(result.value).to eq(policy_last_updated_at)
      end
    end

    context 'when config is nil' do
      let(:policy_object) { { config: nil } }

      it 'returns nil' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to be_nil
      end
    end
  end

  describe '#id' do
    context 'when security policy exists' do
      let_it_be(:security_policy, freeze: false) { create(:security_policy, policy_trait) }
      let(:config) { security_policy.security_orchestration_policy_configuration }
      let(:policy_object) do
        { config: config, type: security_policy.type, policy_index: security_policy.policy_index }
      end

      it 'returns the global ID of the security policy' do
        result = resolve_field(:id, policy_object, object_type: described_class)

        expect(result).to be_a(GraphQL::Execution::Lazy)
        expect(result.value).to eq(security_policy.to_global_id)
      end
    end

    context 'when security policy does not exist' do
      let_it_be(:config, freeze: false) { create(:security_orchestration_policy_configuration) }
      let(:policy_object) { { config: config, type: policy_trait.to_s, policy_index: 0 } }

      it 'returns nil' do
        result = resolve_field(:id, policy_object, object_type: described_class)

        expect(result).to be_a(GraphQL::Execution::Lazy)
        expect(result.value).to be_nil
      end
    end

    context 'when config is nil' do
      let(:policy_object) { { config: nil, type: policy_trait.to_s, policy_index: 0 } }

      it 'returns nil' do
        result = resolve_field(:id, policy_object, object_type: described_class)

        expect(result).to be_nil
      end
    end
  end

  describe '#policy_configuration_id' do
    let_it_be(:config, freeze: false) { create(:security_orchestration_policy_configuration) }

    it 'returns the global ID of the policy configuration' do
      result = resolve_field(:policy_configuration_id, { config: config }, object_type: described_class)

      expect(result).to eq(config.to_global_id)
    end

    context 'when config is nil' do
      it 'returns nil' do
        result = resolve_field(:policy_configuration_id, { config: nil }, object_type: described_class)

        expect(result).to be_nil
      end
    end
  end
end
