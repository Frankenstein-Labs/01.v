# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::RecordLastActivityWorker, :clean_gitlab_redis_shared_state, feature_category: :seat_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:lease_key) { "gitlab_subscriptions:members_activity_event:#{group.id}:#{user.id}" }

  let(:user_id) { user.id }
  let(:namespace_id) { group.id }

  let(:last_activity_event) do
    ::Users::ActivityEvent.new(data: { user_id: user_id, namespace_id: namespace_id })
  end

  context 'in a saas environment', :saas do
    it_behaves_like 'subscribes to event' do
      let(:event) { last_activity_event }
    end

    context 'when the lease_key is taken' do
      before do
        allow(Gitlab::ExclusiveLease).to receive(:get_uuid).with(lease_key).and_return(true)
      end

      it_behaves_like 'ignores the published event' do
        let(:event) { last_activity_event }
      end
    end
  end

  context 'in a self managed environment' do
    it_behaves_like 'ignores the published event' do
      let(:event) { last_activity_event }
    end
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#handle_event' do
    it 'updates the GitlabSubscription::SeatAssignment last_activity_on timestamp' do
      seat_assignment = create(:gitlab_subscription_seat_assignment, :active, user: user, namespace: group)

      expect do
        consume_event(subscriber: described_class, event: last_activity_event)
      end.to change { seat_assignment.reload.last_activity_on }
    end

    shared_examples 'returns early' do
      it do
        expect(::GitlabSubscriptions::Members::ActivityService).not_to receive(:new)

        consume_event(subscriber: described_class, event: last_activity_event)
      end
    end

    context 'when the user is not found' do
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'returns early'
    end

    context 'when the namespace is not found' do
      let(:namespace_id) { non_existing_record_id }

      it_behaves_like 'returns early'
    end
  end
end
