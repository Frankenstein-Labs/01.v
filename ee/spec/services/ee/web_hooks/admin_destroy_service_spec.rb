# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHooks::AdminDestroyService, :sidekiq_inline, feature_category: :webhooks do
  let(:rake_task) { instance_double(Rake::Task, name: 'gitlab:web_hook:rm', present?: true) }
  let_it_be(:project) { create(:project) }
  let(:web_hook) { create(:project_hook, project: project) }
  let(:service) { described_class.new(rake_task: rake_task) }

  describe '#execute' do
    subject(:webhook_destroyed) { service.execute(web_hook) }

    context 'when destroying a project hook succeeds' do
      it 'creates an audit event', :aggregate_failures do
        expect { webhook_destroyed }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          author_id: -1,
          target_type: "ProjectHook",
          target_details: "Hook #{web_hook.id}",
          details: include(custom_message: a_string_including("rake task (#{rake_task.name})"))
        )
      end
    end

    context 'when destroying a project hook fails' do
      before do
        allow(web_hook).to receive(:destroy).and_return(false)
      end

      it 'does not create an audit event' do
        expect { webhook_destroyed }.not_to change { AuditEventReader.count }
      end
    end
  end
end
