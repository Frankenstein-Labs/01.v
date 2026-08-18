# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UnassignRunnerService, '#execute', feature_category: :runner_core do
  let_it_be(:owner_project) { create(:project) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [owner_project, other_project]) }

  let(:runner_project) { project_runner.runner_projects.last }

  subject(:execute) { described_class.new(runner_project, user).execute }

  context 'with unauthorized user' do
    let_it_be(:user) { build(:user) }

    it 'does not call assign_to on runner and returns error response', :aggregate_failures do
      expect(project_runner).not_to receive(:assign_to)
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      is_expected.to be_error
    end
  end

  context 'with admin user', :enable_admin_mode do
    let_it_be(:user) { create(:admin) }

    it 'calls audit on Auditor and returns success response', :aggregate_failures do
      expect(runner_project).to receive(:destroy).once.and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit)
        .with({
          name: 'ci_runner_unassigned_from_project',
          author: user,
          scope: other_project,
          target: project_runner,
          target_details: ::Gitlab::Routing.url_helpers.project_runner_path(owner_project, project_runner),
          message: 'Unassigned CI runner from project'
        })

      is_expected.to be_success
    end
  end
end
