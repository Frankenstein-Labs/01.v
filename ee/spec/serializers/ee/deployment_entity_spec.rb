# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeploymentEntity do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:request) { EntityRequest.new(project: project, current_user: current_user) }

  let(:deployment) { create(:deployment, :blocked, project: project, environment: environment) }
  let(:environment) { create(:environment, project: project) }

  let(:approval_rules) do
    [
      build(
        :protected_environment_approval_rule,
        :maintainer_access,
        required_approvals: 3
      )
    ]
  end

  let!(:protected_environment) do
    create(
      :protected_environment,
      :maintainers_can_deploy,
      name: environment.name,
      project: project,
      approval_rules: approval_rules
    )
  end

  subject { described_class.new(deployment, request: request).as_json }

  before do
    stub_licensed_features(protected_environments: true)
    create(:deployment_approval, deployment: deployment, approval_rule: approval_rules.first)
  end

  describe '#pending_approval_count' do
    it 'exposes pending_approval_count' do
      expect(subject[:pending_approval_count]).to eq(2)
    end
  end

  describe '#approvals' do
    it 'exposes approvals' do
      expect(subject[:approvals].length).to eq(1)
    end
  end

  describe '#can_approve_deployment' do
    context 'when user has permission to update deployment' do
      before_all do
        project.add_maintainer(current_user)
      end

      before do
        create(:protected_environment_deploy_access_level, protected_environment: protected_environment, user: current_user)
      end

      it 'returns true' do
        expect(subject[:can_approve_deployment]).to be(true)
      end
    end

    context 'when user does not have permission to update deployment' do
      it 'returns false' do
        expect(subject[:can_approve_deployment]).to be(false)
      end
    end
  end

  describe '#has_approval_rules' do
    context 'when configured without approval rules' do
      let(:approval_rules) { [] }

      it 'returns false' do
        expect(subject[:has_approval_rules]).to be(false)
      end
    end

    context 'when configured with approval rules' do
      it 'returns true' do
        expect(subject[:has_approval_rules]).to be(true)
      end
    end
  end
end
