# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignment, feature_category: :seat_cost_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:extra_dummy_record) { create(:gitlab_subscription_seat_assignment) }

  subject { build(:gitlab_subscription_seat_assignment) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to belong_to(:organization).inverse_of(:seat_assignments) }
  end

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:user_id) }

    context 'when on GitLab.com', :saas do
      it { is_expected.to validate_presence_of(:namespace_id) }
    end

    context 'when not on GitLab.com' do
      it { is_expected.not_to validate_presence_of(:namespace_id) }
    end
  end

  describe 'scopes' do
    describe '.by_namespace' do
      it 'returns records filtered by namespace' do
        result = create(:gitlab_subscription_seat_assignment, namespace: namespace)

        expect(described_class.by_namespace(namespace)).to match_array(result)
      end
    end

    describe '.by_user' do
      it 'returns records filtered by namespace' do
        result = create(:gitlab_subscription_seat_assignment, user: user)

        expect(described_class.by_user(user)).to match_array(result)
      end
    end
  end

  describe '.find_by_namespace_and_user' do
    it 'returns single record by namespace and user' do
      result = create(:gitlab_subscription_seat_assignment, user: user, namespace: namespace)

      expect(described_class.find_by_namespace_and_user(namespace, user)).to eq(result)
    end
  end

  describe '.by_namespace_and_users' do
    let_it_be(:user_2) { create(:user) }
    let_it_be(:user_3) { create(:user) }
    let_it_be(:seat_assignment_1) { create(:gitlab_subscription_seat_assignment, user: user, namespace: namespace) }
    let_it_be(:seat_assignment_2) { create(:gitlab_subscription_seat_assignment, user: user_2, namespace: namespace) }

    it 'returns records by namespace and users' do
      expect(described_class.by_namespace_and_users(namespace, [user, user_2])).to contain_exactly(
        seat_assignment_1,
        seat_assignment_2
      )
    end

    it 'returns empty array when no records exist' do
      expect(described_class.by_namespace_and_users(namespace, [user_3])).to be_empty
    end
  end

  describe '.dormant_in_namespace', :freeze_time do
    let_it_be(:dormant_seat_assignment_1) do
      create(:gitlab_subscription_seat_assignment, namespace: namespace, last_activity_on: 91.days.ago)
    end

    let_it_be(:dormant_seat_assignment_2) do
      create(:gitlab_subscription_seat_assignment, namespace: namespace, created_at: 101.days.ago)
    end

    before do
      # create active seat assignments:
      create(:gitlab_subscription_seat_assignment, namespace: namespace, last_activity_on: 1.hour.ago)
      create(:gitlab_subscription_seat_assignment, namespace: namespace, last_activity_on: nil, created_at: 10.days.ago)
    end

    it 'includes users' do
      expect(described_class.dormant_in_namespace(namespace).first.association_cached?(:user)).to be true
    end

    context 'with no cut off date passed to scope' do
      it 'returns dormant seat assignment records' do
        expect(described_class.dormant_in_namespace(namespace)).to contain_exactly(
          dormant_seat_assignment_1,
          dormant_seat_assignment_2
        )
      end
    end

    context 'with a cut off date passed to scope' do
      it 'returns seat assignment records dormant for the given cut off date' do
        expect(described_class.dormant_in_namespace(namespace, 100.days.ago)).to contain_exactly(
          dormant_seat_assignment_2
        )
      end
    end
  end

  describe 'enums' do
    let(:seat_types) do
      {
        base: 0,
        free: 1,
        plan: 2,
        system: 3
      }
    end

    it { is_expected.to define_enum_for(:seat_type).with_values(**seat_types) }
  end
end
