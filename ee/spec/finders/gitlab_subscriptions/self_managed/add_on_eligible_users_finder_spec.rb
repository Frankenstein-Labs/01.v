# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder, feature_category: :seat_cost_management do
  describe '#execute' do
    let(:gitlab_duo_pro_finder) { described_class.new(add_on_type: :code_suggestions) }
    let(:gitlab_duo_enterprise_finder) { described_class.new(add_on_type: :duo_enterprise) }

    it 'returns no users for non_gitlab_duo_pro add-on types' do
      non_gitlab_duo_pro_finder = described_class.new(add_on_type: :some_other_addon)
      expect(non_gitlab_duo_pro_finder.execute).to be_empty
    end

    context 'with variety of users' do
      let(:active_user) { create(:user) }
      let(:bot) { create(:user, :bot) }
      let(:ghost) { create(:user, :ghost) }
      let(:blocked_user) { create(:user, :blocked) }
      let(:banned_user) { create(:user, :banned) }
      let(:pending_approval_user) { create(:user, :blocked_pending_approval) }
      let(:group) { create(:group) }
      let(:guest_user) { create(:group_member, :guest, source: group).user }

      it 'returns billable users for gitlab duo pro' do
        expect(gitlab_duo_pro_finder.execute).to include(active_user)
        expect(gitlab_duo_pro_finder.execute).not_to include(bot, ghost, blocked_user, banned_user,
          pending_approval_user)
      end

      it 'returns billable users for gitlab duo enterprise' do
        result = gitlab_duo_enterprise_finder.execute

        expect(result).to include(active_user)
        expect(result).not_to include(bot, ghost, blocked_user, banned_user, pending_approval_user)
      end

      it 'includes guest users for gitlab duo pro' do
        expect(gitlab_duo_pro_finder.execute).to include(guest_user)
      end

      it 'includes guest users for gitlab duo enterprise' do
        expect(gitlab_duo_enterprise_finder.execute).to include(guest_user)
      end
    end

    context 'when supplied a valid search term' do
      let(:matching_user) { create(:user, name: 'Matching User') }
      let(:non_matching_user) { create(:user, name: 'Non') }

      it 'filters users by search term if provided' do
        finder = described_class.new(
          add_on_type: :code_suggestions,
          filter_options: { search_term: 'Matching' }
        )

        expect(finder.execute).to include(matching_user)
        expect(finder.execute).not_to include(non_matching_user)
      end
    end

    context 'when supplied a valid sort term' do
      let_it_be(:user1) { create(:user, name: 'A User', last_activity_on: 1.day.ago) }
      let_it_be(:user2) { create(:user, name: 'B User', last_activity_on: 2.days.ago) }
      let_it_be(:user3) { create(:user, name: 'C User', last_activity_on: 3.days.ago) }
      let(:finder) { described_class.new(add_on_type: :code_suggestions, sort: sort_term) }

      context 'when sorting by name(ASC)' do
        let(:sort_term) { 'name_asc' }

        it 'filters the eligible users by sort term' do
          expect(finder.execute).to eq([user1, user2, user3])
        end
      end

      context 'when sorting by name(DESC)' do
        let(:sort_term) { 'name_desc' }

        it 'filters the eligible users by sort term' do
          expect(finder.execute).to eq([user3, user2, user1])
        end
      end

      context 'when sorting by last_activity(ASC)' do
        let(:sort_term) { 'last_activity_on_asc' }

        it 'filters the eligible users by sort term' do
          expect(finder.execute).to eq([user3, user2, user1])
        end
      end

      context 'when sorting by last_activity(DESC)' do
        let(:sort_term) { 'last_activity_on_desc' }

        it 'filters the eligible users by sort term' do
          expect(finder.execute).to eq([user1, user2, user3])
        end
      end
    end

    context 'when supplied a filter option' do
      let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_pro) }
      let(:assigned_user) { create(:user, name: 'Assigned User') }
      let(:blocked_assigned_user) { create(:user, :blocked, name: 'Blocked Assigned User') }
      let(:non_assigned_user) { create(:user, name: 'Non Assigned User') }

      before do
        add_on_purchase.assigned_users.create!(user: assigned_user)
        add_on_purchase.assigned_users.create!(user: blocked_assigned_user)
      end

      context 'when filter_by_assigned_seat is true' do
        let(:filter_options) { { filter_by_assigned_seat: true } }

        it 'filters users by assigned seats' do
          finder = described_class.new(
            add_on_purchase_id: add_on_purchase.id,
            add_on_type: :code_suggestions,
            filter_options: filter_options
          )

          expect(finder.execute).to include(assigned_user, blocked_assigned_user)
          expect(finder.execute).not_to include(non_assigned_user)
        end
      end

      context 'when filter_by_assigned_seat is false' do
        let(:filter_options) { { filter_by_assigned_seat: false } }

        it 'filters users by not assigned seats' do
          finder = described_class.new(
            add_on_purchase_id: add_on_purchase.id,
            add_on_type: :code_suggestions,
            filter_options: filter_options
          )

          expect(finder.execute).to include(non_assigned_user)
          expect(finder.execute).not_to include(assigned_user)
        end
      end

      context 'when filter_by_assigned_seat is nil' do
        let(:filter_options) { { filter_by_assigned_seat: nil } }

        it 'returns all eligible users without filtering' do
          finder = described_class.new(
            add_on_purchase_id: add_on_purchase.id,
            add_on_type: :code_suggestions,
            filter_options: filter_options
          )

          expect(finder.execute).to include(non_assigned_user, assigned_user)
        end
      end
    end
  end
end
