# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::DestroyedWorker, feature_category: :seat_cost_management do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_namespace) }
  let_it_be(:source) { create(:group, parent: root_namespace) }
  let_it_be_with_reload(:user) { create(:user) }

  let(:root_namespace_id) { root_namespace.id }
  let(:source_id) { source.id }
  let(:source_type) { source.class.name }
  let(:user_id) { user.id }

  let(:members_destroyed_event) do
    ::Members::DestroyedEvent.new(
      data: {
        root_namespace_id: root_namespace_id,
        source_id: source_id,
        source_type: source_type,
        user_id: user_id
      }
    )
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { members_destroyed_event }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#handle_event' do
    shared_examples 'does nothing' do
      specify do
        expect do
          consume_event(subscriber: described_class, event: members_destroyed_event)
        end.not_to change { GitlabSubscriptions::SeatAssignment.count }
      end
    end

    context 'in a self-managed environment' do
      let_it_be_with_reload(:seat_assignment) do
        create(:gitlab_subscription_seat_assignment, user: user, seat_type: :base)
      end

      it_behaves_like 'does nothing'
    end

    context 'in a saas environment', :saas do
      let_it_be_with_reload(:seat_assignment) do
        create(:gitlab_subscription_seat_assignment, namespace: root_namespace, user: user, seat_type: :base)
      end

      it 'destroys SeatAssignment record' do
        expect do
          consume_event(subscriber: described_class, event: members_destroyed_event)
        end.to change { GitlabSubscriptions::SeatAssignment.where(namespace: root_namespace, user: user).count }.by(-1)
      end

      context 'when there is no seat assignment record related to user' do
        let(:user_id) { create(:user).id }

        it "does not destroy others' seat_assignment records" do
          expect do
            consume_event(subscriber: described_class, event: members_destroyed_event)
          end.not_to change { GitlabSubscriptions::SeatAssignment.count }
        end
      end

      context 'when user is not found' do
        let(:user_id) { non_existing_record_id }

        it_behaves_like 'does nothing'
      end

      context 'when root namespace is not found' do
        let(:root_namespace_id) { non_existing_record_id }

        it_behaves_like 'does nothing'
      end

      context 'when root namespace is not group' do
        let(:user_namespace) { create(:user_namespace) }
        let(:root_namespace_id) { user_namespace.id }

        it_behaves_like 'does nothing'
      end

      context 'when user is still a member of group hierarchy' do
        before_all do
          subgroup.add_guest(user)
        end

        it_behaves_like 'does nothing'

        context 'when the user is blocked' do
          before do
            user.block!
          end

          it_behaves_like 'does nothing'
        end
      end

      context 'when user is still a member of project hierarchy' do
        let(:project) { build(:project, group: root_namespace) }

        before do
          project.add_guest(user)
        end

        it_behaves_like 'does nothing'
      end

      context 'when an access request remains' do
        before do
          create(:group_member, :access_request, source: subgroup, user: user)
        end

        it 'removes the seat assignment' do
          expect do
            consume_event(subscriber: described_class, event: members_destroyed_event)
          end.to change {
                   GitlabSubscriptions::SeatAssignment.where(namespace: root_namespace, user: user).count
                 }.by(-1)
        end
      end

      context 'when a pending membership remains' do
        before do
          create(:group_member, :awaiting, source: subgroup, user: user)
        end

        it 'removes the seat assignment' do
          expect do
            consume_event(subscriber: described_class, event: members_destroyed_event)
          end.to change {
                   GitlabSubscriptions::SeatAssignment.where(namespace: root_namespace, user: user).count
                 }.by(-1)
        end
      end

      context 'when an invited membership remains' do
        before do
          create(:group_member, :invited, source: subgroup, user: user)
        end

        it 'removes the seat assignment' do
          expect do
            consume_event(subscriber: described_class, event: members_destroyed_event)
          end.to change {
                   GitlabSubscriptions::SeatAssignment.where(namespace: root_namespace, user: user).count
                 }.by(-1)
        end
      end

      context 'when a base seat has only guest memberships remaining on a free plan' do
        before_all do
          subgroup.add_guest(user)
        end

        it 'leaves the seat type base' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('base')
        end
      end

      context 'when a base seat has only guest memberships remaining on a premium plan' do
        before_all do
          create(:gitlab_subscription, :premium, namespace: root_namespace)
          subgroup.add_guest(user)
        end

        it 'leaves the seat type base' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('base')
        end
      end

      context 'when a base seat has only guest memberships remaining on an ultimate plan' do
        before_all do
          create(:gitlab_subscription, :ultimate, namespace: root_namespace)
          subgroup.add_guest(user)
        end

        it 'changes the seat type to free' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('free')
        end
      end

      context 'when a base seat has only planner memberships remaining on an ultimate plan' do
        before_all do
          create(:gitlab_subscription, :ultimate, namespace: root_namespace)
          subgroup.add_planner(user)
        end

        it 'changes the seat type to plan' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('plan')
        end
      end

      context 'when a base seat has a remaining membership higher than planner on an ultimate plan' do
        before_all do
          create(:gitlab_subscription, :ultimate, namespace: root_namespace)
          root_namespace.add_guest(user)
          subgroup.add_developer(user)
        end

        it 'leaves the seat type base' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('base')
        end
      end

      context 'when a free seat has a membership higher than planner remaining on an ultimate plan' do
        before_all do
          seat_assignment.update!(seat_type: :free)
          create(:gitlab_subscription, :ultimate, namespace: root_namespace)
          root_namespace.add_developer(user)
        end

        it 'updates the seat type to base' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('base')
        end
      end

      context 'when a seat has no type set but has memberships' do
        before_all do
          seat_assignment.update!(seat_type: nil)
          create(:gitlab_subscription, :premium, namespace: root_namespace)
          subgroup.add_guest(user)
        end

        it 'updates the seat type' do
          consume_event(subscriber: described_class, event: members_destroyed_event)

          seat = ::GitlabSubscriptions::SeatAssignment.find_by(namespace: root_namespace, user: user)

          expect(seat.seat_type).to eq('base')
        end
      end
    end
  end
end
