# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::NamespaceAccessCacheResetWorker, feature_category: :mcp_server do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:sub_group) { create(:group, parent: group) }

  let_it_be(:group_member) { create(:group_member, group: group, user: create(:user)) }
  let_it_be(:sub_group_member) { create(:group_member, group: sub_group, user: create(:user)) }
  let_it_be(:project_member) { create(:project_member, project: project, user: create(:user)) }

  let(:source_id) { group.id }
  let(:data) { { group_id: source_id } }
  let(:event) { Mcp::ServerSettingsChangedEvent.new(data: data) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed
  it_behaves_like 'subscribes to event'

  context 'when group cannot be found' do
    let(:source_id) { non_existing_record_id }

    it 'does not clear cache' do
      expect(User).not_to receive(:clear_group_with_mcp_server_enabled_cache)

      consume_event(subscriber: described_class, event: event)
    end
  end

  context 'when group is found' do
    let(:affected_user_ids) { [group_member.user.id, sub_group_member.user.id, project_member.user.id] }

    it 'clears MCP cache for affected users regardless of AI license' do
      expect(User).to receive(:clear_group_with_mcp_server_enabled_cache).with(match_array(affected_user_ids))

      consume_event(subscriber: described_class, event: event)
    end
  end

  context 'when a user is a member multiple times' do
    let_it_be(:duplicate_member) { create(:group_member, group: sub_group, user: project_member.user) }

    let(:affected_user_ids) { [group_member.user.id, sub_group_member.user.id, project_member.user.id] }

    it 'deduplicates users before clearing cache' do
      expect(User).to receive(:clear_group_with_mcp_server_enabled_cache).with(match_array(affected_user_ids))

      consume_event(subscriber: described_class, event: event)
    end
  end
end
