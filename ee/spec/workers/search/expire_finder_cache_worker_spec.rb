# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::ExpireFinderCacheWorker, feature_category: :global_search do
  let(:worker) { described_class.new }

  describe 'event subscriptions' do
    it 'is subscribed to AuthorizationsAddedEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[ProjectAuthorizations::AuthorizationsAddedEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to AuthorizationsRemovedEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[ProjectAuthorizations::AuthorizationsRemovedEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to MembersAddedEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[Members::MembersAddedEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to Members::DestroyedEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[Members::DestroyedEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to Members::UpdatedEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[Members::UpdatedEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to Members::AcceptedInviteEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[Members::AcceptedInviteEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end

    it 'is subscribed to Members::MembershipModifiedByAdminEvent' do
      subscriptions = Gitlab::EventStore.instance.subscriptions[Members::MembershipModifiedByAdminEvent]

      expect(subscriptions.map(&:worker)).to include(described_class)
    end
  end

  describe '#handle_event' do
    let_it_be(:user) { create(:user) }

    it 'expires the cache for the user_ids' do
      event = instance_double(Gitlab::EventStore::Event, data: { user_ids: [user.id] })

      expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([user.id])
      expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([user.id])

      worker.handle_event(event)
    end

    it 'expires cache for multiple user_ids in a single call' do
      event = instance_double(Gitlab::EventStore::Event, data: { user_ids: [1, 2, 3] })

      expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([1, 2, 3])
      expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([1, 2, 3])

      worker.handle_event(event)
    end

    it 'does nothing when user_ids is empty' do
      event = instance_double(Gitlab::EventStore::Event, data: { user_ids: [] })

      expect(::Search::GroupsFinder).not_to receive(:expire_cache_for_users)
      expect(::Search::ProjectsFinder).not_to receive(:expire_cache_for_users)

      worker.handle_event(event)
    end

    it 'does nothing when user_ids is nil' do
      event = instance_double(Gitlab::EventStore::Event, data: { user_ids: nil })

      expect(::Search::GroupsFinder).not_to receive(:expire_cache_for_users)
      expect(::Search::ProjectsFinder).not_to receive(:expire_cache_for_users)

      worker.handle_event(event)
    end

    it 'writes new version values for each affected user with one write_multi per finder' do
      user_ids = [user.id, user.id + 1]
      event = instance_double(Gitlab::EventStore::Event, data: { user_ids: user_ids })

      expect(Rails.cache).to receive(:write_multi).with(
        hash_including(
          ::Search::GroupsFinder.cache_version_key(user_ids[0]) => kind_of(String),
          ::Search::GroupsFinder.cache_version_key(user_ids[1]) => kind_of(String)
        ),
        expires_in: ::Search::GroupsFinder::CACHE_VERSION_TTL
      ).ordered

      expect(Rails.cache).to receive(:write_multi).with(
        hash_including(
          ::Search::ProjectsFinder.cache_version_key(user_ids[0]) => kind_of(String),
          ::Search::ProjectsFinder.cache_version_key(user_ids[1]) => kind_of(String)
        ),
        expires_in: ::Search::ProjectsFinder::CACHE_VERSION_TTL
      ).ordered

      worker.handle_event(event)
    end

    context 'with Members::UpdatedCloudEvent payload' do
      let_it_be(:project) { create(:project) }

      it 'extracts user IDs from event_data' do
        event = Members::UpdatedCloudEvent.build(
          source: project, current_user: user, user_ids: [user.id]
        )

        expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([user.id])
        expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([user.id])

        worker.handle_event(event)
      end
    end

    context 'with MembersAddedEvent payload' do
      it 'extracts user IDs from invited_user_ids' do
        event = instance_double(Gitlab::EventStore::Event,
          data: { source_id: 1, source_type: 'Namespace', invited_user_ids: [user.id] })

        expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([user.id])
        expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([user.id])

        worker.handle_event(event)
      end
    end

    context 'with Members::DestroyedEvent payload' do
      it 'extracts user ID from user_id field' do
        event = instance_double(Gitlab::EventStore::Event,
          data: { source_id: 1, source_type: 'Namespace', user_id: user.id })

        expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([user.id])
        expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([user.id])

        worker.handle_event(event)
      end
    end

    context 'with Members::MembershipModifiedByAdminEvent payload' do
      it 'extracts user ID from member_user_id field' do
        event = instance_double(Gitlab::EventStore::Event, data: { member_user_id: user.id })

        expect(::Search::GroupsFinder).to receive(:expire_cache_for_users).with([user.id])
        expect(::Search::ProjectsFinder).to receive(:expire_cache_for_users).with([user.id])

        worker.handle_event(event)
      end
    end
  end
end
