# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::SetRunnerAssociatedProjectsService, '#execute', feature_category: :runner_core do
  subject(:execute) do
    described_class.new(runner: project_runner, current_user: user, project_ids: projects_ids).execute
  end

  let_it_be(:owner_project) { create(:project) }
  let_it_be(:existing_project) { create(:project) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [owner_project, existing_project]) }
  let_it_be(:new_projects) { create_list(:project, 2, organization: owner_project.organization) }

  let(:projects_ids) { new_projects.map(&:id) }

  before do
    stub_licensed_features(audit_events: true, extended_audit_events: true)
  end

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
    let_it_be(:user) { create(:user, :admin) }

    context 'with assign_to returning true' do
      it 'calls audit on Auditor and returns success response', :aggregate_failures do
        new_projects.each do |new_project|
          expect(project_runner).to receive(:assign_to).with(new_project, user).once.and_return(true)
        end

        expected_runner_url = ::Gitlab::Routing.url_helpers.project_runner_path(
          project_runner.owner,
          project_runner)
        common_attrs = {
          author: user,
          target: project_runner,
          target_details: expected_runner_url
        }
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          a_hash_including(
            **common_attrs,
            name: 'set_runner_associated_projects',
            message: 'Changed CI runner project assignments',
            scope: owner_project,
            additional_details: {
              action: :custom,
              deleted_from_projects: [existing_project.id],
              added_project_ids: new_projects.map(&:id)
            }
          )).and_call_original
        new_projects.each do |new_project|
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            a_hash_including(
              **common_attrs,
              name: 'set_runner_associated_projects',
              message: 'Assigned CI runner to project',
              scope: new_project
            )).and_call_original
        end
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          a_hash_including(
            **common_attrs,
            name: 'set_runner_associated_projects',
            message: 'Unassigned CI runner from project',
            scope: existing_project
          )).and_call_original

        expect(execute).to be_success

        event = AuditEventReader.by_entity_id(owner_project).last
        expect(event).to be_an_instance_of(AuditEvents::ProjectAuditEvent)
        expect(event.author).to eq(user)
        expect(event.target_id).to eq(project_runner.id)
        expect(event.target_type).to eq(Ci::Runner.name)
        expect(event.details).to match(a_hash_including(
          custom_message: 'Changed CI runner project assignments',
          event_name: 'set_runner_associated_projects',
          author_name: user.name,
          target_details: expected_runner_url,
          deleted_from_projects: [existing_project.id],
          added_project_ids: new_projects.map(&:id)))

        new_projects.each do |new_project|
          event = AuditEventReader.by_entity_id(new_project).last
          expect(event).to be_an_instance_of(AuditEvents::ProjectAuditEvent)
          expect(event.author).to eq(user)
          expect(event.details[:custom_message]).to include('Assigned CI runner to project')
          expect(event.target_id).to eq(project_runner.id)
          expect(event.target_type).to eq(Ci::Runner.name)
        end

        event = AuditEventReader.by_entity_id(existing_project).last
        expect(event).to be_an_instance_of(AuditEvents::ProjectAuditEvent)
        expect(event.author).to eq(user)
        expect(event.details[:custom_message]).to include('Unassigned CI runner from project')
        expect(event.target_id).to eq(project_runner.id)
        expect(event.target_type).to eq(Ci::Runner.name)
        expect(event.target_details).to eq(
          ::Gitlab::Routing.url_helpers.project_runner_path(owner_project, project_runner))
      end
    end

    context 'with assign_to returning false' do
      let(:projects_ids) { [new_projects.first.id] }

      it 'does not call audit on Auditor and returns error response', :aggregate_failures do
        expect(project_runner).to receive(:assign_to).with(new_projects.first, user).once.and_return(false)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        expect(execute).to be_error
        expect(execute.reason).to eq :runner_error
      end
    end
  end
end
