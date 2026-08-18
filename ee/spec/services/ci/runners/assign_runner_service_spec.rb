# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::AssignRunnerService, '#execute', feature_category: :runner_core do
  let_it_be(:owner_project) { create(:project) }
  let_it_be(:new_project) { create(:project, organization: owner_project.organization) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [owner_project]) }

  let(:params) { {} }

  subject(:execute) { described_class.new(project_runner, new_project, user, **params).execute }

  context 'with unauthorized user' do
    let(:user) { build(:user) }

    it 'does not call assign_to on runner and returns error response', :aggregate_failures do
      expect(project_runner).not_to receive(:assign_to)
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      expect(execute).to be_error
      expect(execute.reason).to eq :not_authorized_to_assign_runner
    end
  end

  context 'with admin user', :enable_admin_mode do
    let(:user) { create(:admin) }

    context 'with assign_to returning true' do
      it 'calls track_event on Gitlab::Audit::Auditor and returns success response', :aggregate_failures do
        expect(project_runner).to receive(:assign_to).with(new_project, user).once.and_return(true)
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'ci_runner_assigned_to_project',
          author: user,
          scope: new_project,
          target: project_runner,
          target_details: ::Gitlab::Routing.url_helpers.project_runner_path(owner_project, project_runner),
          message: 'Assigned CI runner to project'
        })

        is_expected.to be_success
      end

      context 'when quiet is set to true' do
        let(:params) { { quiet: true } }

        it 'does not call Gitlab::Audit::Auditor and returns success response', :aggregate_failures do
          expect(project_runner).to receive(:assign_to).with(new_project, user).once.and_return(true)
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          is_expected.to be_success
        end
      end
    end

    context 'with assign_to returning false' do
      it 'does not call Gitlab::Audit::Auditor and returns error response', :aggregate_failures do
        expect(project_runner).to receive(:assign_to).with(new_project, user).once.and_return(false)
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        is_expected.to be_error
        expect(execute.reason).to eq :runner_error
      end
    end
  end
end
