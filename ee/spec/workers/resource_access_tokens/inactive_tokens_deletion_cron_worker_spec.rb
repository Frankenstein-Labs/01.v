# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceAccessTokens::InactiveTokensDeletionCronWorker, feature_category: :system_access do
  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'for audit event' do
      let(:resource) { create(:group) }
      let!(:project_bot) do
        create(
          :resource_access_token,
          resource: resource,
          expires_at: Gitlab::CurrentSettings.inactive_resource_access_tokens_delete_after_days.days.ago - 1.day
        ).user
      end

      it(
        "logs user_destroyed audit event linked to the project bot resource",
        :freeze_time, :sidekiq_inline, :aggregate_failures
      ) do
        expect { worker.perform }.to change {
          AuditEventReader.where("details LIKE ?", "%user_destroyed%").count
        }.by(1)

        audit_event = AuditEventReader.where("details LIKE ?", "%user_destroyed%").last

        author = Users::Internal.in_organization(resource.organization).admin_bot
        expect(audit_event.author_id).to eq(author.id)
        expect(audit_event.entity).to eq(resource)
        expect(audit_event.details).to eq({
          event_name: 'user_destroyed',
          author_class: author.class.to_s,
          author_name: author.name,
          custom_message:
            "User #{project_bot.username} scheduled for deletion. Reason: No active token assigned",
          target_details: project_bot.full_path,
          target_id: project_bot.id,
          target_type: project_bot.class.to_s
        })
      end
    end
  end
end
