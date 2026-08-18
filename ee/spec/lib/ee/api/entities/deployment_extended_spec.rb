# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::DeploymentExtended do
  subject { ::API::Entities::DeploymentExtended.new(deployment).as_json }

  describe '#as_json' do
    let(:deployment) { create(:deployment, :blocked) }

    let(:protected_environment) do
      create(:protected_environment, project_id: deployment.environment.project_id, name: deployment.environment.name)
    end

    let(:deployment_approval) do
      create(:deployment_approval, :approved, deployment: deployment, approval_rule: protected_environment_approval_rule)
    end

    let(:protected_environment_approval_rule) do
      create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment, required_approvals: 2)
    end

    before do
      stub_licensed_features(protected_environments: true)
      protected_environment
      deployment_approval
      protected_environment_approval_rule
    end

    it 'includes fields from deployment entity' do
      is_expected.to include(:id, :iid, :ref, :sha, :created_at, :updated_at, :user, :environment, :deployable, :status)
    end

    it 'includes pending_approval_count' do
      expect(subject[:pending_approval_count]).to eq(1)
    end

    it 'includes approvals', :aggregate_failures do
      expect(subject[:approvals].length).to eq(1)
      expect(subject.dig(:approvals, 0, :status)).to eq("approved")
    end

    it 'includes approval summary' do
      expect(subject[:approval_summary][:rules].first[:required_approvals]).to eq(2)
    end
  end
end
