# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoveExpiredMembersWorker, feature_category: :system_access do
  let(:worker) { described_class.new }

  describe '#perform' do
    context 'for project bots' do
      let(:project) { create(:project) }
      let!(:project_bot) { create(:resource_access_token, resource: project).user }

      context 'for audit event' do
        before do
          project_bot.members.first.update_column(:expires_at, 1.second.ago)
        end

        it "logs user_destroyed audit event linked to the project bot resource", :aggregate_failures do
          expect { worker.perform }.to change {
            AuditEventReader.where("details LIKE ?", "%user_destroyed%").count
          }.by(1)

          audit_event = AuditEventReader.where("details LIKE ?", "%user_destroyed%").last

          author = ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)')
          expect(audit_event.author_id).to eq(author.id)
          expect(audit_event.entity).to eq(project)
          expect(audit_event.details).to eq({
            event_name: 'user_destroyed',
            author_class: author.class.to_s,
            author_name: author.name,
            custom_message:
              "User #{project_bot.username} scheduled for deletion. Reason: Membership expired",
            target_details: project_bot.full_path,
            target_id: project_bot.id,
            target_type: project_bot.class.to_s
          })
        end
      end
    end
  end
end
