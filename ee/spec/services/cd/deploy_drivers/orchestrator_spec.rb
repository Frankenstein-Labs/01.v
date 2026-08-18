# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::DeployDrivers::Orchestrator, feature_category: :continuous_delivery do
  subject(:orchestrator) { described_class.for_gem('gitlab-cd-driver-orchestration') }

  describe '.for_gem' do
    it 'resolves the gem directory via Gem.loaded_specs' do
      expect(orchestrator).to be_a(described_class)
    end
  end

  # Pins the manifest key names so a gem bump that renames one fails here.
  describe '#flow_definition_schema' do
    it 'parses the gem-vendored flow definition JSON Schema' do
      expect(orchestrator.flow_definition_schema).to include('required' => ['steps'])
    end
  end

  describe '#assemble' do
    let(:driver) { ::Cd::DeployDrivers::Registry.find('argo-rollouts') }

    # The real vendored fragment, not a stub, so a bad gem bump fails CI.
    subject(:program) { orchestrator.assemble(driver_scripts: { driver.gem_name => driver.deploy_fragment }) }

    it 'puts the engine entrypoint in front of the driver fragment', :aggregate_failures do
      expect(program).to include('def main(')
      expect(program.index('def main(')).to be < program.index('def gitlab_ddeploy_ddriver_dargo_drollouts_deploy(')
    end

    it 'invokes the renamed fragment so its step handlers register before main runs' do
      expect(program).to match(/^gitlab_ddeploy_ddriver_dargo_drollouts_deploy\(\)$/)
    end

    it 'leaves no bare deploy() for a second fragment to collide with' do
      expect(program).not_to include("\ndef deploy(")
    end

    it 'returns a binary-encoded string, as KAS expects' do
      expect(program.encoding).to eq(Encoding::ASCII_8BIT)
    end

    context 'when a fragment is not a fragment at all' do
      it 'raises, rather than sending a program that cannot load' do
        expect { orchestrator.assemble(driver_scripts: { 'some-gem' => "x = 1\n" }) }
          .to raise_error(ArgumentError, /no module-level/)
      end
    end
  end
end
