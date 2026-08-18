# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Processor, feature_category: :audit_events do
  describe '.fetch_from_json' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let_it_be(:author) { create(:user) }
    let_it_be(:target_user) { create(:user) }

    context 'when JSON has entity_type and entity_id but no specific *_id key (stream_only events)' do
      let(:stream_only_event_json) do
        {
          author_id: author.id,
          entity_id: project.id,
          entity_type: 'Project',
          created_at: Time.current,
          details: { custom_message: 'stream only event', event_name: 'repository_git_operation' }
        }.to_json
      end

      it 'correctly identifies and creates a ProjectAuditEvent from entity_type/entity_id' do
        result = described_class.fetch_from_json(stream_only_event_json)

        expect(result).to be_a(::AuditEvents::ProjectAuditEvent)
        expect(result.project_id).to eq(project.id)
      end

      context 'with a Group entity_type' do
        let(:stream_only_group_event_json) do
          {
            author_id: author.id,
            entity_id: group.id,
            entity_type: 'Group',
            created_at: Time.current,
            details: { custom_message: 'stream only event' }
          }.to_json
        end

        it 'correctly identifies and creates a GroupAuditEvent from entity_type/entity_id' do
          result = described_class.fetch_from_json(stream_only_group_event_json)

          expect(result).to be_a(::AuditEvents::GroupAuditEvent)
          expect(result.group_id).to eq(group.id)
        end
      end

      context 'with a User entity_type' do
        let(:stream_only_user_event_json) do
          {
            author_id: author.id,
            entity_id: target_user.id,
            entity_type: 'User',
            created_at: Time.current,
            details: { custom_message: 'stream only event' }
          }.to_json
        end

        it 'correctly identifies and creates a UserAuditEvent from entity_type/entity_id' do
          result = described_class.fetch_from_json(stream_only_user_event_json)

          expect(result).to be_a(::AuditEvents::UserAuditEvent)
          expect(result.user_id).to eq(target_user.id)
        end
      end

      context 'with an InstanceScope entity_type' do
        let(:stream_only_instance_event_json) do
          {
            author_id: author.id,
            entity_id: 1,
            entity_type: 'Gitlab::Audit::InstanceScope',
            created_at: Time.current,
            details: { custom_message: 'stream only event' }
          }.to_json
        end

        it 'correctly identifies and creates an InstanceAuditEvent' do
          result = described_class.fetch_from_json(stream_only_instance_event_json)

          expect(result).to be_a(::AuditEvents::InstanceAuditEvent)
        end
      end
    end
  end
end
