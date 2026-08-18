# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHooks::DestroyService, :sidekiq_inline, feature_category: :webhooks do
  let_it_be(:current_user) { create(:user) }

  describe '#execute' do
    # Testing with a project hook only - for permission tests, see policy specs.
    let_it_be(:hook) { create(:project_hook) }

    subject(:webhook_destroyed) { described_class.new(current_user).execute(hook) }

    context 'when destroying a project hook succeeds' do
      before do
        hook.project.add_maintainer(current_user)
      end

      it 'creates an audit event', :aggregate_failures do
        expect { webhook_destroyed }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          author_name: current_user.name,
          author_id: current_user.id,
          target_type: "ProjectHook",
          target_details: "Hook #{hook.id}",
          details: include(custom_message: "Deleted project hook")
        )
      end
    end

    context 'when destroying a project hook fails' do
      before do
        allow(hook).to receive(:destroy).and_return(false)
      end

      it 'does not create an audit event' do
        expect { webhook_destroyed }.not_to change { AuditEventReader.count }
      end
    end
  end
end
