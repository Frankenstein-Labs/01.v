# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::BulkUserAssignment, feature_category: :'add-on_provisioning' do
  describe '#initialize' do
    subject(:bulk_assignment) { described_class.new([], nil) }

    it 'initializes with the correct attributes' do
      expect(bulk_assignment.usernames).to eq([])
      expect(bulk_assignment.add_on_purchase).to be_nil
      expect(bulk_assignment.successful_assignments).to eq([])
      expect(bulk_assignment.failed_assignments).to eq([])
    end
  end

  describe '#execute' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    # The tests are dependent on the order of usernames in this list.
    # Do not reorder without updating the corresponding test expectations.
    let_it_be(:usernames) do
      %w[
        code_suggestions_active_user1
        code_suggestions_active_user2
        code_suggestions_active_user3
        code_suggestions_extra_user1
        code_suggestions_extra_user2
        code_suggestions_blocked_user
        code_suggestions_banned_user
        code_suggestions_bot_user
        code_suggestions_ghost_user
        code_suggestions_not_found_username
      ]
    end

    subject(:bulk_assignment) { described_class.new(usernames, add_on_purchase) }

    shared_examples 'bulk user assignment with enough seats' do
      it 'returns success and failed assignments' do
        results = bulk_assignment.execute

        expect(results[:successful_assignments]).to match_array([
          "User assigned: code_suggestions_active_user1",
          "User assigned: code_suggestions_active_user2",
          "User assigned: code_suggestions_active_user3",
          "User assigned: code_suggestions_extra_user1",
          "User assigned: code_suggestions_extra_user2"
        ])

        expect(results[:failed_assignments]).to match_array([
          "Failed to assign seat to user: code_suggestions_blocked_user, Errors: [\"INVALID_USER_MEMBERSHIP\"]",
          "Failed to assign seat to user: code_suggestions_banned_user, Errors: [\"INVALID_USER_MEMBERSHIP\"]",
          "Failed to assign seat to user: code_suggestions_bot_user, Errors: [\"INVALID_USER_MEMBERSHIP\"]",
          "Failed to assign seat to user: code_suggestions_ghost_user, Errors: [\"INVALID_USER_MEMBERSHIP\"]",
          "User is not found: code_suggestions_not_found_username"
        ])
      end

      it 'uses throttling' do
        stub_const("#{described_class}::THROTTLE_BATCH_SIZE", 5)
        stub_const("#{described_class}::THROTTLE_SLEEP_DELAY", 0.0001)

        expect(bulk_assignment).to receive(:sleep).with(0.0001).and_call_original

        bulk_assignment.execute
      end
    end

    shared_examples 'bulk user assignment with not enough seats' do
      it 'returns success and failed assignments and stops execution' do
        results = bulk_assignment.execute

        expect(results[:successful_assignments]).to eq(
          ["User assigned: code_suggestions_active_user1",
            "User assigned: code_suggestions_active_user2",
            "User assigned: code_suggestions_active_user3"])

        expect(results[:failed_assignments]).to eq(
          ["Failed to assign seat to user: code_suggestions_extra_user1, Errors: [\"NO_SEATS_AVAILABLE\"]",
            "##No seats are left; users starting from @code_suggestions_extra_user1 onwards were not assigned.##"])
      end
    end

    context 'when the AddOn is not purchased' do
      it 'returns a message indicating AddOn not purchased' do
        results = described_class.new([], nil).execute
        expect(results).to eq('AddOn not purchased')
      end
    end

    context 'on self managed instances' do
      before do
        create(:user, username: 'code_suggestions_active_user1')
        create(:user, username: 'code_suggestions_active_user2')
        create(:user, username: 'code_suggestions_active_user3')
        create(:user, username: 'code_suggestions_extra_user1')
        create(:user, username: 'code_suggestions_extra_user2')
        create(:user, :blocked, username: 'code_suggestions_blocked_user')
        create(:user, :banned, username: 'code_suggestions_banned_user')
        create(:user, :bot, username: 'code_suggestions_bot_user')
        create(:user, :ghost, username: 'code_suggestions_ghost_user')
      end

      context 'when the AddOn is purchased' do
        context 'with enough seats' do
          include_examples 'bulk user assignment with enough seats' do
            let(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, quantity: 10, add_on: add_on)
            end
          end
        end

        context 'with not enough seats' do
          include_examples 'bulk user assignment with not enough seats' do
            let(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, quantity: 3, add_on: add_on)
            end
          end
        end
      end
    end

    context 'on Gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      let_it_be(:namespace) { create(:group) }

      context 'with bulk assignment' do
        before_all do
          namespace.add_developer(create(:user, username: 'code_suggestions_active_user1'))
          namespace.add_developer(create(:user, username: 'code_suggestions_active_user2'))
          namespace.add_developer(create(:user, username: 'code_suggestions_active_user3'))
          namespace.add_developer(create(:user, username: 'code_suggestions_extra_user1'))
          namespace.add_developer(create(:user, username: 'code_suggestions_extra_user2'))
          namespace.add_developer(create(:user, :blocked, username: 'code_suggestions_blocked_user'))
          namespace.add_developer(create(:user, :banned, username: 'code_suggestions_banned_user'))
          namespace.add_developer(create(:user, :bot, username: 'code_suggestions_bot_user'))
          namespace.add_developer(create(:user, :ghost, username: 'code_suggestions_ghost_user'))
        end

        context 'with enough seats' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, quantity: 10, namespace: namespace, add_on: add_on)
          end

          include_examples 'bulk user assignment with enough seats'
        end

        context 'with not enough seats' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, quantity: 3, namespace: namespace, add_on: add_on)
          end

          include_examples 'bulk user assignment with not enough seats'
        end
      end
    end
  end
end
