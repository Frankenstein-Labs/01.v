# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Status::Bridge::WaitingForApproval, feature_category: :deployment_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:job) { create(:ci_bridge, :manual, environment: 'production', project: project) }

  subject(:status) { described_class.new(Gitlab::Ci::Status::Core.new(job, user)) }

  it_behaves_like 'a deployment job waiting for approval', :ci_bridge

  describe '#status_tooltip' do
    it { expect(status.status_tooltip).to eq('View deployment details page') }
  end

  describe '#deployment_details_path' do
    let!(:environment) { create(:environment, name: 'production', project: project) }
    let!(:deployment) { create(:deployment, :blocked, project: project, environment: environment, deployable: job) }

    it 'points to the deployment details page' do
      expected_path = Rails.application.routes.url_helpers.project_environment_deployment_path(
        project, environment, deployment)
      expect(status.deployment_details_path).to eq expected_path
    end
  end
end
