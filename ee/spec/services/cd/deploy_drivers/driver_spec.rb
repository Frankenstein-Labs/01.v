# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::DeployDrivers::Driver, feature_category: :continuous_delivery do
  subject(:driver) { described_class.for_gem('gitlab-deploy-driver-argo-rollouts') }

  describe '.for_gem' do
    it 'resolves the gem directory via Gem.loaded_specs' do
      expect(driver).to be_a(described_class)
    end
  end

  describe '#gem_name' do
    it 'retains the gem name it was resolved from, which the assembler keys fragments by' do
      expect(driver.gem_name).to eq('gitlab-deploy-driver-argo-rollouts')
    end
  end

  describe '#environment_schema' do
    it 'parses the gem-vendored environment JSON Schema' do
      expect(driver.environment_schema).to include('required' => ['cluster_agent_id'])
    end

    it 'rejects a driver config carrying anything the schema does not declare' do
      expect(driver.environment_schema).to include('additionalProperties' => false)
    end
  end

  describe '#application_environment_schema' do
    it 'parses the gem-vendored service_environment JSON Schema' do
      expect(driver.application_environment_schema).to include(
        'required' => %w[namespace application manifest_repository]
      )
    end
  end

  describe '#steps_schema' do
    it 'parses the gem-vendored steps JSON Schema, covering every supported step type' do
      step_types = driver.steps_schema['oneOf'].map { |schema| schema.dig('properties', 'type', 'const') }

      expect(step_types).to contain_exactly(
        'com.gitlab.cd.argo.rolling.deploy',
        'com.gitlab.cd.argo.canary.deploy',
        'com.gitlab.cd.argo.canary.promote'
      )
    end
  end

  describe '#deploy_fragment' do
    it 'reads the gem-vendored deploy fragment' do
      expect(driver.deploy_fragment).to include('def deploy(')
    end

    # Regression guard: 0.4.0 moved main() to the engine.
    it 'is a fragment, not a standalone program' do
      expect(driver.deploy_fragment).not_to include('def main(')
    end

    # Regression guard: read as binary, this could not be joined with the engine's UTF-8
    # main.star once both carried non-ASCII bytes, and assembling raised instead.
    it 'reads in the same encoding as the engine program it is concatenated with' do
      expect(driver.deploy_fragment.encoding)
        .to eq(::Gitlab::Cd::Driver::Orchestration.main_program.encoding)
    end
  end
end
