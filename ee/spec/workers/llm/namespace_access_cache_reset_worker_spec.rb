# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::NamespaceAccessCacheResetWorker, :saas, feature_category: :ai_abstraction_layer do
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:sub_group) { create(:group, parent: group) }

  let_it_be(:group_member) { create(:group_member, group: group, user: create(:user)) }
  let_it_be(:sub_group_member) { create(:group_member, group: sub_group, user: create(:user)) }
  let_it_be(:project_member) { create(:project_member, project: project, user: create(:user)) }

  let(:source_id) { group.id }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  shared_examples 'success' do
    context 'when namespace has AI features' do
      before do
        stub_licensed_features(ai_features: true)
      end

      context 'when namespace can not be found' do
        let(:source_id) { non_existing_record_id }

        it 'does not clear cache' do
          expect(User).not_to receive(:clear_group_with_ai_available_cache)

          consume_event(subscriber: described_class, event: event)
        end
      end

      context 'when namespace can be found' do
        it 'clears cache for affected users' do
          expect(User).to receive(:clear_group_with_ai_available_cache).with(affected_user_ids)

          consume_event(subscriber: described_class, event: event)
        end
      end

      context 'when user is member multiple times', :use_clean_rails_redis_caching do
        let_it_be(:group_member2) { create(:group_member, group: sub_group, user: project_member.user) }

        it 'calls cache deletion only once for a user' do
          expect(User).to receive(:clear_group_with_ai_available_cache).with(affected_user_ids)

          consume_event(subscriber: described_class, event: event)
        end
      end
    end

    context 'when namespace has no AI features' do
      before do
        stub_licensed_features(ai_features: false)
      end

      it 'does not clear cache for any user' do
        expect(User).not_to receive(:clear_group_with_ai_available_cache)

        consume_event(subscriber: described_class, event: event)
      end
    end
  end

  context 'when AiRelatedSettingsChangedEvent' do
    let(:data) { { group_id: source_id } }
    let(:event) { NamespaceSettings::AiRelatedSettingsChangedEvent.new(data: data) }
    let(:affected_user_ids) { [group_member.user.id, sub_group_member.user.id, project_member.user.id] }

    it_behaves_like 'subscribes to event'
    it_behaves_like 'success'
  end

  context 'when MembersAddedEvent for a group' do
    let(:data) { { source_id: source_id, source_type: group.class.to_s } }
    let(:event) { Members::MembersAddedEvent.new(data: data) }
    let(:affected_user_ids) { [group_member.user.id] }

    let_it_be(:existing_member) do
      create(:group_member, group: group, user: create(:user), created_at: (1.hour + 1.minute).ago)
    end

    it_behaves_like 'subscribes to event'
    it_behaves_like 'success'
  end

  context 'when MembersAddedEvent for a project' do
    let(:source_id) { project.id }
    let(:data) { { source_id: source_id, source_type: project.class.to_s } }
    let(:event) { Members::MembersAddedEvent.new(data: data) }
    let(:affected_user_ids) { [project_member.user.id] }

    let_it_be(:existing_member) do
      create(:project_member, project: project, user: create(:user), created_at: (1.hour + 1.minute).ago)
    end

    it_behaves_like 'subscribes to event'
    it_behaves_like 'success'
  end
end
