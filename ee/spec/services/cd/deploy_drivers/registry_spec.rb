# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::DeployDrivers::Registry, feature_category: :continuous_delivery do
  describe '.find' do
    it 'returns the driver registered for a known driver_ref' do
      driver = described_class.find('argo-rollouts')

      expect(driver).to be_a(Cd::DeployDrivers::Driver)
    end

    it 'memoizes the driver instance across calls' do
      expect(described_class.find('argo-rollouts')).to equal(described_class.find('argo-rollouts'))
    end

    it 'returns nil for an unregistered driver_ref' do
      expect(described_class.find('unknown-driver')).to be_nil
    end
  end

  describe '.orchestrator' do
    it 'returns the orchestration engine' do
      expect(described_class.orchestrator).to be_a(Cd::DeployDrivers::Orchestrator)
    end

    it 'memoizes the orchestrator instance across calls' do
      expect(described_class.orchestrator).to equal(described_class.orchestrator)
    end
  end

  describe '.driver_refs' do
    it 'returns every registered driver_ref' do
      expect(described_class.driver_refs).to contain_exactly('argo-rollouts')
    end

    it 'excludes the orchestration engine, which no environment binds to' do
      expect(described_class.driver_refs).not_to include(described_class::ORCHESTRATION_GEM)
    end
  end
end
