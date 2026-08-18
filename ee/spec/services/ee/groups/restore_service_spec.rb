# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::RestoreService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }

  # reload clears previous_changes on group settings from the create
  let(:group) { create(:group, :deletion_scheduled, owners: user).reload }

  subject(:execute) { described_class.new(group, user, {}).execute }

  context 'for cache invalidation', :use_clean_rails_memory_store_caching do
    it 'invalidates the free group upgrade link cache' do
      cache_key = ['users', user.id, 'free_group_upgrade_link']
      GitlabSubscriptions::FreeGroupUpgradeLinkCache.get(user.id) { 'cached_value' }

      execute

      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  context 'for audit events' do
    it 'logs audit event', :aggregate_failures do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_restored')
      ).and_call_original

      expect { execute }.to change { AuditEventReader.count }.by(1)
    end
  end
end
