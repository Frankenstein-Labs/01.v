# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Subscribable, feature_category: :team_planning do
  let_it_be(:user1) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:work_item_epic) { epic.work_item }

  describe '#set_subscription' do
    shared_examples 'sets subscription' do
      let(:expected_subscribable) { subscribable.is_a?(WorkItem) ? Issue.find(subscribable.id) : subscribable }

      subject(:unsubscribe) { subscribable.set_subscription(user1, false) }

      context 'with existing subscription on the subscribable' do
        let_it_be(:subscription) do
          create(:subscription, user: user1, subscribable: subscribable, subscribed: true, project: nil)
        end

        it 'updates subscription state for the subscribable' do
          expect { unsubscribe }
            .to change { subscription.reload.subscribed }.to(false)
            .and not_change { Subscription.count }
        end
      end

      context 'with existing subscription on the synced object' do
        let_it_be(:subscription) do
          create(:subscription, user: user1, subscribable: synced_object, subscribed: true, project: nil)
        end

        it 'updates subscription state for the synced object' do
          expect { unsubscribe }
            .to change { subscription.reload.subscribed }.to(false)
            .and not_change { Subscription.count }
        end
      end

      context 'with existing subscription on subscribable and synced object' do
        let_it_be(:synced_object_subscription) do
          create(:subscription, user: user1, subscribable: synced_object, subscribed: true, project: nil)
        end

        let_it_be(:subscribable_subscription) do
          create(:subscription, user: user1, subscribable: subscribable, subscribed: true, project: nil)
        end

        it 'updates latest subscription record' do
          expect { unsubscribe }
            .to change { subscribable_subscription.reload.subscribed }.to(false)
            .and not_change { synced_object_subscription.subscribed }
        end
      end

      context 'with no existing subscription record' do
        it 'creates subscription record for the subscribable' do
          expect { unsubscribe }.to change { Subscription.count }.by(1)

          new_subscription = Subscription.last
          expect(new_subscription.user).to eq(user1)
          expect(new_subscription.subscribable).to eq(expected_subscribable)
          expect(new_subscription.subscribed).to be(false)
        end
      end

      context 'with other project-level subscriptions' do
        let(:project) { create(:project, group: group) }
        let(:issue) { create(:issue, project: project) }

        let!(:issue_subscription) do
          create(:subscription, user: user1, subscribable: issue, subscribed: true, project: project)
        end

        it 'does not update unrelated subscriptions' do
          expect { unsubscribe }.to change { Subscription.count }.by(1)

          expect(issue_subscription.reload.subscribed).to be(true)
        end
      end
    end

    context 'when subscribable is an Epic' do
      let_it_be(:subscribable) { epic }
      let_it_be(:synced_object) { work_item_epic }

      it_behaves_like 'sets subscription'
    end

    context 'when subscribable is a Work item of type Epic' do
      let_it_be(:subscribable) { work_item_epic }
      let_it_be(:synced_object) { epic }

      it_behaves_like 'sets subscription'
    end
  end

  describe '#subscribed?' do
    shared_examples 'returns subscription state' do
      context 'when subscribable has a subscription record' do
        before do
          create(:subscription, user: user1, subscribable: subscribable, subscribed: true, project: nil)
        end

        it 'returns true for subscribable and the synced object' do
          expect(subscribable.subscribed?(user1)).to be(true)
          expect(synced_object.subscribed?(user1)).to be(true)
        end
      end

      context 'when subscribable and synced_object have a subscription record' do
        it 'returns state of the latest subscription record' do
          create(:subscription, user: user1, subscribable: subscribable, subscribed: true, project: nil)
          create(:subscription, user: user1, subscribable: synced_object, subscribed: false, project: nil)

          expect(subscribable.subscribed?(user1)).to be(false)
          expect(synced_object.subscribed?(user1)).to be(false)
        end
      end
    end

    context 'when subscribable is an Epic' do
      let_it_be(:subscribable) { epic }
      let_it_be(:synced_object) { work_item_epic }

      it_behaves_like 'returns subscription state'
    end

    context 'when subscribable is a Work item of type Epic' do
      let_it_be(:subscribable) { work_item_epic }
      let_it_be(:synced_object) { epic }

      it_behaves_like 'returns subscription state'
    end
  end

  describe '#subscribers' do
    let_it_be(:user2) { create(:user) }

    shared_examples 'find subscribers' do
      subject(:subscribers) { subscribable.subscribers(nil) }

      context 'with existing subscription on the subscribable' do
        it 'gets subscribers from the subscribable' do
          [user1, user2].each do |user|
            create(:subscription, user: user, subscribable: subscribable, subscribed: true, project: nil)
          end

          is_expected.to contain_exactly(user1, user2)
        end
      end

      context 'with existing subscription on the synced object' do
        it 'gets subscribers from the work item' do
          [user1, user2].each do |user|
            create(:subscription, user: user, subscribable: synced_object, subscribed: true, project: nil)
          end

          is_expected.to contain_exactly(user1, user2)
        end
      end

      context 'with existing subscription on the subscribable and the synced object' do
        let_it_be(:subscribable_subscription) do
          create(:subscription, user: user2, subscribable: subscribable, subscribed: true, project: nil)
        end

        let_it_be(:synced_object_subscription) do
          create(:subscription, user: user1, subscribable: synced_object, subscribed: true, project: nil)
        end

        it 'gets subscribers from the subscribable and the synced object' do
          is_expected.to contain_exactly(user1, user2)
        end
      end
    end

    context 'when subscribable is an Epic' do
      let_it_be(:subscribable) { epic }
      let_it_be(:synced_object) { work_item_epic }

      it_behaves_like 'find subscribers'
    end

    context 'when subscribable is a Work item of type Epic' do
      let_it_be(:subscribable) { work_item_epic }
      let_it_be(:synced_object) { epic }

      it_behaves_like 'find subscribers'
    end
  end
end
