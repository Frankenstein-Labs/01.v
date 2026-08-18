# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::AddedWorker, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:source_id) { group.id }
  let(:source_type) { group.class.name }
  let(:invited_user_ids) { [user.id] }
  let(:members_added_event) do
    ::Members::MembersAddedEvent.new(
      data: { source_id: source_id, source_type: source_type, invited_user_ids: invited_user_ids }
    )
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { members_added_event }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#handle_event' do
    it 'calls service to handle recently added members' do
      expect_next_instance_of(::GitlabSubscriptions::Members::AddedService, group, invited_user_ids) do |service|
        expect(service).to receive(:execute)
      end

      consume_event(subscriber: described_class, event: members_added_event)
    end

    context 'when the source is not found' do
      let(:source_id) { non_existing_record_id }

      it 'returns early' do
        expect(::GitlabSubscriptions::Members::AddedService).not_to receive(:new)

        consume_event(subscriber: described_class, event: members_added_event)
      end
    end

    context 'when invited_user_ids property is not present' do
      let(:members_added_event) do
        ::Members::MembersAddedEvent.new(
          data: { source_id: source_id, source_type: source_type }
        )
      end

      it 'returns early' do
        expect(::GitlabSubscriptions::Members::AddedService).not_to receive(:new)

        consume_event(subscriber: described_class, event: members_added_event)
      end
    end
  end
end
