# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }

  subject(:result) { described_class.new(group, user, {}).execute }

  context 'for audit events' do
    it 'logs audit event' do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_deletion_marked')
      ).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_name_updated')
      ).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_path_updated')
      ).and_call_original

      expect { result }.to change { AuditEventReader.count }.by(3)
    end
  end

  context 'for cache invalidation', :use_clean_rails_memory_store_caching do
    it 'invalidates the free group upgrade link cache' do
      cache_key = ['users', user.id, 'free_group_upgrade_link']
      GitlabSubscriptions::FreeGroupUpgradeLinkCache.get(user.id) { 'cached_value' }

      result

      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  context 'when containing linked security policy project' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:policy_project) { create(:project, group: subgroup) }
    let_it_be(:policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        namespace: subgroup,
        project: nil,
        security_policy_management_project: policy_project
      )
    end

    context 'with licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq(
          'Group cannot be deleted because it has projects that are linked as a security policy project'
        )
      end
    end

    context 'without licensed feature' do
      it 'succeeds' do
        expect(result).to be_success
      end
    end
  end
end
