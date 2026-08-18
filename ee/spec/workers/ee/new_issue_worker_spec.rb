# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NewIssueWorker, feature_category: :team_planning do
  let_it_be(:project) { create(:project) }

  describe '#perform' do
    let(:worker) { described_class.new }

    context 'when project bot it logs audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com", maintainer_of: project) }

      include_examples 'audit event logging' do
        let(:issue) { create(:issue, title: "My issue", project: project, author: project_bot) }
        let(:operation) { worker.perform(issue.id, project_bot.id) }
        let(:event_type) { 'issue_created_by_project_bot' }
        let(:fail_condition!) { allow_any_instance_of(User).to receive(:project_bot?).and_return(false) } # rubocop:disable RSpec/AnyInstanceOf
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: issue.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: "issue_created_by_project_bot",
              target_id: issue.id,
              target_type: 'Issue',
              target_details: {
                iid: issue.iid,
                id: issue.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Created issue #{issue.title}"
            }
          }
        end
      end
    end

    context 'when project bot creates a ticket it logs audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com", maintainer_of: project) }

      include_examples 'audit event logging' do
        let(:ticket) { create(:issue, :ticket, title: "My ticket", project: project, author: project_bot) }
        let(:operation) { worker.perform(ticket.id, project_bot.id) }
        let(:event_type) { 'ticket_created_by_project_bot' }
        let(:fail_condition!) { allow_any_instance_of(User).to receive(:project_bot?).and_return(false) } # rubocop:disable RSpec/AnyInstanceOf -- User is loaded from DB
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: ticket.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: "ticket_created_by_project_bot",
              target_id: ticket.id,
              target_type: 'Issue',
              target_details: {
                iid: ticket.iid,
                id: ticket.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Created ticket #{ticket.title}"
            }
          }
        end
      end
    end
  end
end
