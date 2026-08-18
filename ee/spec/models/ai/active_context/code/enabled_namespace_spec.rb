# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ActiveContext::Code::EnabledNamespace, feature_category: :global_search do
  include LooseForeignKeysHelper

  let_it_be(:namespace) { create(:group) }
  let_it_be(:connection) { create(:ai_active_context_connection) }
  let_it_be(:inactive_connection) { create(:ai_active_context_connection, :inactive) }
  let_it_be(:ultimate_plan) { create(:ultimate_plan) }
  let_it_be(:premium_plan) { create(:premium_plan) }

  let_it_be(:namespace1) { create(:group) }
  let_it_be(:namespace2) { create(:group) }
  let_it_be(:namespace3) { create(:group) }
  let_it_be(:enabled_namespace1) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
      active_context_connection: connection)
  end

  let_it_be(:enabled_namespace2) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace2,
      active_context_connection: connection)
  end

  let_it_be(:enabled_namespace3) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace3,
      active_context_connection: connection)
  end

  describe 'scopes' do
    describe '.namespace_id_in' do
      it 'returns enabled namespaces with matching namespace IDs' do
        result = described_class.namespace_id_in([namespace1.id, namespace2.id])

        expect(result).to contain_exactly(enabled_namespace1, enabled_namespace2)
      end
    end

    describe '.with_active_connection' do
      let_it_be(:namespace_with_inactive_connection) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: inactive_connection)
      end

      it 'returns enabled namespaces with active connections' do
        result = described_class.with_active_connection

        expect(result).to contain_exactly(enabled_namespace1, enabled_namespace2, enabled_namespace3)
      end
    end

    describe '.ordered_by_id' do
      it 'returns enabled namespaces ordered by id ascending' do
        result = described_class.ordered_by_id

        expect(result.pluck(:id))
          .to match_array([enabled_namespace1.id, enabled_namespace2.id, enabled_namespace3.id].sort)
      end
    end

    describe '.id_greater_than' do
      it 'returns enabled namespaces with id greater than the specified value' do
        result = described_class.id_greater_than(enabled_namespace1.id)

        expect(result).to contain_exactly(enabled_namespace2, enabled_namespace3)
      end

      it 'returns empty when no records have greater id' do
        result = described_class.id_greater_than(enabled_namespace3.id)

        expect(result).to be_empty
      end
    end

    describe '.valid_saas_namespaces', :saas do
      let_it_be(:group_with_valid_subscription_and_experiment_features) do
        create(:group).tap do |group|
          group.namespace_settings.update!(experiment_features_enabled: true)
          create(:gitlab_subscription, namespace: group, hosted_plan: ultimate_plan)
        end
      end

      let_it_be(:group_with_valid_subscription) do
        create(:group_with_plan, plan: :ultimate_plan)
      end

      let_it_be(:group_with_premium_subscription) do
        create(:group_with_plan, plan: :premium_plan)
      end

      let_it_be(:subgroup) do
        create(:group, parent: group_with_valid_subscription)
      end

      let_it_be(:group_without_plan) { create(:group) }

      let_it_be(:group_with_expired_subscription) do
        create(:group).tap do |group|
          create(:gitlab_subscription, :expired, namespace: group, hosted_plan: ultimate_plan)
        end
      end

      it 'returns only top-level groups with valid subscriptions' do
        result = described_class.valid_saas_namespaces

        expect(result).to contain_exactly(
          group_with_valid_subscription,
          group_with_valid_subscription_and_experiment_features,
          group_with_premium_subscription
        )
      end

      it 'excludes subgroups' do
        result = described_class.valid_saas_namespaces

        expect(result).not_to include(subgroup)
      end

      it 'excludes groups without AI supported plan' do
        result = described_class.valid_saas_namespaces

        expect(result).not_to include(group_without_plan)
      end

      it 'excludes groups with expired subscriptions' do
        result = described_class.valid_saas_namespaces

        expect(result).not_to include(group_with_expired_subscription)
      end
    end
  end

  describe 'validations' do
    subject(:enabled_namespace) do
      create(:ai_active_context_code_enabled_namespace, connection_id: connection.id, namespace: namespace)
    end

    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:active_context_connection) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_uniqueness_of(:connection_id).scoped_to(:namespace_id) }

    describe 'metadata' do
      it 'is valid for empty hash' do
        enabled_namespace.metadata = {}
        expect(enabled_namespace).to be_valid
      end

      it 'is invalid for a random hash' do
        enabled_namespace.metadata = { key: 'value' }
        expect(enabled_namespace).not_to be_valid
      end
    end

    describe '#valid_namespace' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let_it_be(:project_namespace) { create(:project_namespace) }

      it 'is valid for root group namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: namespace,
          connection_id: connection.id)

        expect(enabled_namespace).to be_valid
      end

      it 'is invalid for subgroup namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: subgroup,
          connection_id: connection.id)

        expect(enabled_namespace).not_to be_valid
        expect(enabled_namespace.errors[:namespace]).to include('must be a root group.')
      end

      it 'is invalid for project namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: project_namespace,
          connection_id: connection.id)

        expect(enabled_namespace).not_to be_valid
        expect(enabled_namespace.errors[:namespace]).to include('must be a root group.')
      end
    end
  end

  describe 'foreign key constraints' do
    it_behaves_like 'it has loose foreign keys' do
      let(:factory_name) { :ai_active_context_code_enabled_namespace }
    end

    describe 'when namespace is deleted' do
      let_it_be(:enabled_namespace) { create(:ai_active_context_code_enabled_namespace, namespace: namespace) }

      it 'deletes the enabled_namespace' do
        expect(enabled_namespace.namespace_id).to eq(namespace.id)

        namespace.destroy!

        expect { enabled_namespace.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'when connection is deleted' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) do
          create(:ai_active_context_code_enabled_namespace, connection_id: connection.id, namespace: namespace)
        end

        let!(:parent) { connection }
      end
    end
  end
end
