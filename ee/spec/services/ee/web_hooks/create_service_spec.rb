# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHooks::CreateService, :sidekiq_inline, feature_category: :webhooks do
  let_it_be(:current_user) { create(:user) }

  describe '#execute' do
    # Testing with a project hook only - for permission tests, see policy specs.
    let_it_be(:project) { create(:project) }
    let_it_be(:relation) { ProjectHook.none }
    let(:hook_params) { { url: 'https://example.com/hook', project_id: project.id } }

    subject(:webhook_created) { described_class.new(current_user) }

    context 'when creating a project hook succeeds' do
      it 'creates an audit event', :aggregate_failures do
        webhook_created.execute(hook_params, relation)

        expect(AuditEventReader.last).to have_attributes(
          author_name: current_user.name,
          author_id: current_user.id,
          target_type: "ProjectHook",
          target_details: "Hook #{ProjectHook.last.id}",
          details: include(custom_message: "Created project hook")
        )
      end
    end

    context 'when creating a project hook fails' do
      it 'does not create an audit event' do
        hook_params[:url] = 'invalid_url'

        response = webhook_created.execute(hook_params, relation)

        expect { response }.not_to change { AuditEventReader.count }
      end
    end
  end
end
