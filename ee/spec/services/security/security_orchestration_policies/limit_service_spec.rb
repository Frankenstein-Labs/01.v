# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::LimitService, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let(:service) { described_class.new(container: group) }

  shared_examples 'per configuration limit' do |namespace_setting:, instance_setting:|
    context 'when both root ancestor and current settings have limits set' do
      before do
        allow(group.root_ancestor).to receive(namespace_setting)
          .and_return(group_level_setting)
        allow(Gitlab::CurrentSettings).to receive(instance_setting).and_return(7)
      end

      context 'when current setting is set to non-zero value' do
        let(:group_level_setting) { 3 }

        it 'returns the group-level setting' do
          expect(limit).to eq(3)
        end
      end

      context 'when current setting is set to 0' do
        let(:group_level_setting) { 0 }

        it 'returns the root ancestor limit' do
          expect(limit).to eq(7)
        end
      end
    end

    context 'when only root ancestor limit is set' do
      before do
        allow(group.root_ancestor).to receive(namespace_setting).and_return(4)
        allow(Gitlab::CurrentSettings).to receive(instance_setting).and_return(nil)
      end

      it 'returns the root ancestor limit' do
        expect(limit).to eq(4)
      end
    end

    context 'when only current settings limit is set' do
      before do
        allow(group.root_ancestor).to receive(namespace_setting).and_return(nil)
        allow(Gitlab::CurrentSettings).to receive(instance_setting).and_return(6)
      end

      it 'returns the current settings limit' do
        expect(limit).to eq(6)
      end
    end

    context 'when no limits are set' do
      before do
        allow(group.root_ancestor).to receive(namespace_setting).and_return(nil)
        allow(Gitlab::CurrentSettings).to receive(instance_setting).and_return(nil)
      end

      it 'returns the default limit' do
        expect(limit).to eq(5)
      end
    end

    context 'when root_ancestor is nil' do
      before do
        allow(group).to receive(:root_ancestor).and_return(nil)
        allow(Gitlab::CurrentSettings).to receive(instance_setting).and_return(nil)
      end

      it 'returns the default limit' do
        expect(limit).to eq(5)
      end
    end
  end

  describe '#pipeline_execution_policies_per_pipeline_limit' do
    subject(:limit) { service.pipeline_execution_policies_per_pipeline_limit }

    it 'returns the default limit' do
      expect(limit).to eq(5)
    end
  end

  describe '#pipeline_execution_policies_per_configuration_limit' do
    subject(:limit) { service.pipeline_execution_policies_per_configuration_limit }

    it_behaves_like 'per configuration limit',
      namespace_setting: :pipeline_execution_policies_per_configuration_limit,
      instance_setting: :pipeline_execution_policies_per_configuration_limit
  end

  describe '#scan_execution_policies_per_configuration_limit' do
    subject(:limit) { service.scan_execution_policies_per_configuration_limit }

    it_behaves_like 'per configuration limit',
      namespace_setting: :scan_execution_policies_per_configuration_limit,
      instance_setting: :scan_execution_policies_per_configuration_limit
  end

  describe '#approval_policies_per_configuration_limit' do
    subject(:limit) { service.approval_policies_per_configuration_limit }

    it_behaves_like 'per configuration limit',
      namespace_setting: :approval_policies_per_configuration_limit,
      instance_setting: :security_approval_policies_limit
  end

  describe '#vulnerability_management_policies_per_configuration_limit' do
    subject(:limit) { service.vulnerability_management_policies_per_configuration_limit }

    it_behaves_like 'per configuration limit',
      namespace_setting: :vulnerability_management_policies_per_configuration_limit,
      instance_setting: :vulnerability_management_policies_per_configuration_limit
  end

  describe '#dependency_firewall_policies_per_configuration_limit' do
    subject(:limit) { service.dependency_firewall_policies_per_configuration_limit }

    it_behaves_like 'per configuration limit',
      namespace_setting: :dependency_firewall_policies_per_configuration_limit,
      instance_setting: :dependency_firewall_policies_per_configuration_limit
  end
end
