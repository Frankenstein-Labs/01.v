# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationFlowDefinitions::Document, feature_category: :continuous_delivery do
  subject(:document) { described_class.new(parsed) }

  def stage(name, *steps)
    { 'type' => 'com.gitlab.cd.steps.stage', 'name' => name, 'steps' => steps }
  end

  def deploy(environment)
    { 'type' => 'com.gitlab.cd.argo.rolling.deploy', 'environment' => environment }
  end

  def wait(seconds)
    { 'type' => 'com.gitlab.cd.steps.wait', 'seconds' => seconds }
  end

  describe '#leaf_steps' do
    context 'when the flow mixes stages with standalone common steps' do
      let(:parsed) do
        { 'steps' => [stage('staging', deploy('staging')), wait(30), stage('production', deploy('production'))] }
      end

      it 'unrolls each stage in place, keeping flow order' do
        expect(document.leaf_steps).to eq([deploy('staging'), wait(30), deploy('production')])
      end
    end

    context 'when a stage groups several steps' do
      let(:parsed) { { 'steps' => [stage('production', deploy('production'), wait(60))] } }

      it 'returns them in order' do
        expect(document.leaf_steps).to eq([deploy('production'), wait(60)])
      end
    end

    context 'when the document is not a Hash' do
      let(:parsed) { %w[production staging] }

      it 'returns no steps rather than raising' do
        expect(document.leaf_steps).to be_empty
      end
    end

    context 'when steps is absent' do
      let(:parsed) { { 'environments' => {} } }

      it 'returns no steps' do
        expect(document.leaf_steps).to be_empty
      end
    end

    context 'when a member is not a mapping' do
      let(:parsed) { { 'steps' => ['production', stage('production', deploy('production'), 'nope')] } }

      it 'skips it, at both levels' do
        expect(document.leaf_steps).to eq([deploy('production')])
      end
    end
  end

  describe '#driver_steps' do
    let(:parsed) { { 'steps' => [wait(30), stage('production', deploy('production'), wait(60))] } }

    it 'excludes the steps the orchestration engine owns' do
      expect(document.driver_steps).to eq([deploy('production')])
    end

    context 'when a step type is outside the engine namespace' do
      let(:parsed) { { 'steps' => [stage('production', { 'type' => 'deploy' })] } }

      it 'is treated as a driver step, so an unknown type still reaches driver validation' do
        expect(document.driver_steps).to eq([{ 'type' => 'deploy' }])
      end
    end

    context 'when a step has no type' do
      let(:parsed) { { 'steps' => [stage('production', { 'environment' => 'production' })] } }

      it 'is treated as a driver step' do
        expect(document.driver_steps).to eq([{ 'environment' => 'production' }])
      end
    end
  end

  describe '#steps_with_paths' do
    def step(type:, name: nil, environment: nil, params: nil)
      Cd::ApplicationFlowDefinitions::Document::Step.new(
        type: type, name: name, environment: environment, params: params
      )
    end

    context 'when the flow mixes a stage with standalone common steps' do
      let(:parsed) do
        { 'steps' => [stage('production', deploy('production'), wait(60)), wait(30)] }
      end

      it 'assigns a path to every node, including the stage itself, and the correct parent_path' do
        expect(document.steps_with_paths).to eq([
          ['0', nil, step(type: 'com.gitlab.cd.steps.stage', name: 'production')],
          ['0.0', '0', step(type: 'com.gitlab.cd.argo.rolling.deploy', environment: 'production')],
          ['0.1', '0', step(type: 'com.gitlab.cd.steps.wait', params: { 'seconds' => 60 })],
          ['1', nil, step(type: 'com.gitlab.cd.steps.wait', params: { 'seconds' => 30 })]
        ])
      end
    end

    context 'when a stage is empty' do
      let(:parsed) { { 'steps' => [stage('production')] } }

      it 'still returns the stage itself' do
        expect(document.steps_with_paths).to eq([
          ['0', nil, step(type: 'com.gitlab.cd.steps.stage', name: 'production')]
        ])
      end
    end

    context 'when the document is not a Hash' do
      let(:parsed) { %w[production staging] }

      it 'returns no steps rather than raising' do
        expect(document.steps_with_paths).to be_empty
      end
    end

    context 'when a step carries its own configuration alongside its attributes' do
      let(:parsed) do
        { 'steps' => [{ 'type' => 'com.gitlab.cd.argo.canary.deploy', 'environment' => 'production',
                        'services' => [{ 'name' => 'nginx', 'weight' => 33 }] }] }
      end

      it 'splits node attributes from step-specific params' do
        _path, _parent_path, deploy_step = document.steps_with_paths.first

        expect(deploy_step).to have_attributes(
          type: 'com.gitlab.cd.argo.canary.deploy',
          environment: 'production',
          params: { 'services' => [{ 'name' => 'nginx', 'weight' => 33 }] }
        )
      end
    end
  end

  describe '#environment_names' do
    context 'when several steps target the same environment' do
      let(:parsed) do
        {
          'steps' => [
            stage('production', { 'type' => 'com.gitlab.cd.argo.canary.deploy', 'environment' => 'production' }),
            stage('promote', { 'type' => 'com.gitlab.cd.argo.canary.promote', 'environment' => 'production' })
          ]
        }
      end

      it 'names it once' do
        expect(document.environment_names).to eq(['production'])
      end
    end

    context 'when steps target several environments' do
      let(:parsed) { { 'steps' => [stage('staging', deploy('staging')), stage('production', deploy('production'))] } }

      it 'returns them in the order the steps first name them' do
        expect(document.environment_names).to eq(%w[staging production])
      end
    end

    context 'when no step names an environment' do
      let(:parsed) { { 'steps' => [wait(30)] } }

      it 'returns none' do
        expect(document.environment_names).to be_empty
      end
    end
  end
end
