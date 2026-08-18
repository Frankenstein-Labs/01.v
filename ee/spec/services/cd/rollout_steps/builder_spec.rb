# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::RolloutSteps::Builder, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:rollout) do
    create(:cd_rollout, organization: organization, application: application, version_set: version_set)
  end

  let_it_be(:production) { create(:cd_environment, organization: organization, name: 'production') }
  let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout, environment: production) }

  let(:parsed) do
    {
      'steps' => [
        {
          'type' => 'com.gitlab.cd.steps.stage',
          'name' => 'production',
          'steps' => [
            {
              'type' => 'com.gitlab.cd.argo.canary.deploy',
              'environment' => 'production',
              'services' => [{ 'name' => 'nginx', 'weight' => 33 }]
            }
          ]
        },
        { 'type' => 'com.gitlab.cd.steps.wait', 'seconds' => 30 }
      ]
    }
  end

  let(:document) { Cd::ApplicationFlowDefinitions::Document.new(parsed) }

  subject(:steps) do
    described_class.new(
      rollout: rollout,
      document: document,
      rollout_environments_by_name: { 'production' => rollout_environment }
    ).steps
  end

  it 'builds one unsaved rollout step per node in the tree' do
    expect(steps.map(&:persisted?)).to all(be false)
    expect(steps.size).to eq(3)
  end

  it 'assigns path, parent_path and step_type from the flow definition' do
    stage, deploy, wait = steps

    expect(stage).to have_attributes(path: '0', parent_path: nil, step_type: 'com.gitlab.cd.steps.stage',
      name: 'production')
    expect(deploy).to have_attributes(path: '0.0', parent_path: '0', step_type: 'com.gitlab.cd.argo.canary.deploy')
    expect(wait).to have_attributes(path: '1', parent_path: nil, step_type: 'com.gitlab.cd.steps.wait')
  end

  it 'copies step-specific configuration into params' do
    _stage, deploy, wait = steps

    expect(deploy.params).to eq('services' => [{ 'name' => 'nginx', 'weight' => 33 }])
    expect(wait.params).to eq('seconds' => 30)
  end

  it 'links a step to its rollout_environment only when the step names one' do
    stage, deploy, wait = steps

    expect(stage.rollout_environment).to be_nil
    expect(deploy.rollout_environment).to eq(rollout_environment)
    expect(wait.rollout_environment).to be_nil
  end

  it 'assigns the rollout and its organization to every step' do
    expect(steps).to all(have_attributes(rollout: rollout, organization: rollout.organization))
  end
end
