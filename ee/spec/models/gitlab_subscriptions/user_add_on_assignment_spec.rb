# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignment, feature_category: :seat_cost_management do
  describe 'associations' do
    it { is_expected.to belong_to(:user).inverse_of(:assigned_add_ons) }
    it { is_expected.to belong_to(:add_on_purchase).inverse_of(:assigned_users) }
    it { is_expected.to belong_to(:organization).inverse_of(:user_add_on_assignments) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:add_on_purchase) }

    context 'for uniqueness' do
      subject { build(:gitlab_subscription_user_add_on_assignment) }

      it { is_expected.to validate_uniqueness_of(:add_on_purchase_id).scoped_to(:user_id) }
    end
  end

  describe 'scopes' do
    describe '.by_user' do
      it 'returns assignments associated with user' do
        user = create(:user)
        add_on_purchase = create(:gitlab_subscription_add_on_purchase)

        user_assignment = create(
          :gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user
        )
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase) # second assignment

        expect(described_class.count).to eq(2)

        expect(described_class.by_user(user)).to match_array([user_assignment])
      end
    end

    describe '.for_user_ids' do
      context 'when supplied an empty array' do
        it 'returns no assignments' do
          create(:gitlab_subscription_user_add_on_assignment)

          expect(described_class.for_user_ids([])).to be_empty
        end
      end

      context 'when supplied user IDs that do not exist' do
        it 'returns no assignments' do
          create(:gitlab_subscription_user_add_on_assignment)

          expect(described_class.for_user_ids(non_existing_record_id)).to be_empty
        end
      end

      context 'when supplied user IDs for assigned users' do
        it 'returns the assignments for those users' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase)

          matching_assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

          expect(described_class.for_user_ids([matching_assignment.user_id])).to match_array [matching_assignment]
        end
      end

      context 'when supplied user IDs without assignments' do
        it 'returns no assignments' do
          create(:gitlab_subscription_user_add_on_assignment)
          unassigned_user = create(:user)

          expect(described_class.for_user_ids([unassigned_user.id])).to be_empty
        end
      end
    end

    describe '.for_add_on_purchases' do
      it 'returns assignments associated with add-on purchases' do
        purchase = create(:gitlab_subscription_add_on_purchase, :duo_pro)
        assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)
        purchases = ::GitlabSubscriptions::AddOnPurchase.where(id: purchase.id)

        expect(described_class.for_add_on_purchases(purchases)).to eq [assignment]
      end
    end

    describe '.for_active_add_on_purchases' do
      context 'when the assignment is for an active addon purchase' do
        it 'is included in the scope' do
          purchase = create(:gitlab_subscription_add_on_purchase, :duo_pro)
          assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)
          purchases = ::GitlabSubscriptions::AddOnPurchase.where(id: purchase.id)

          expect(described_class.for_active_add_on_purchases(purchases)).to eq [assignment]
        end
      end

      context 'when the assignment is for an expired addon purchase' do
        it 'is not included in the scope' do
          purchase = create(:gitlab_subscription_add_on_purchase, :duo_pro, expires_on: 1.week.ago)
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)
          purchases = ::GitlabSubscriptions::AddOnPurchase.where(id: purchase.id)

          expect(described_class.for_active_add_on_purchases(purchases)).to be_empty
        end
      end

      context 'when there are no assignments for an active gitlab duo pro purchase' do
        it 'returns an empty relation' do
          purchase = create(:gitlab_subscription_add_on_purchase, :duo_pro)
          purchases = ::GitlabSubscriptions::AddOnPurchase.where(id: purchase.id)

          expect(described_class.for_active_add_on_purchases(purchases)).to be_empty
        end
      end
    end

    shared_examples 'filters for active gitlab duo purchase' do
      context 'when the assignment is for an active gitlab duo purchase' do
        it 'is included in the scope' do
          purchase = create(:gitlab_subscription_add_on_purchase, tested_add_on_type)
          assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)

          expect(scope_result).to eq [assignment]
        end
      end

      context 'when the assignment is for an expired gitlab duo purchase' do
        it 'is not included in the scope' do
          purchase = create(:gitlab_subscription_add_on_purchase, tested_add_on_type, expires_on: 1.week.ago)
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)

          expect(scope_result).to be_empty
        end
      end

      context 'when the assignment is for a non-gitlab duo add on' do
        it 'is not included in the scope' do
          add_on = create(:gitlab_subscription_add_on).tap { |add_on| add_on.update_column(:name, -1) }
          purchase = create(:gitlab_subscription_add_on_purchase, add_on: add_on)
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase)

          expect(scope_result).to be_empty
        end
      end

      context 'when there are no assignments for an active gitlab duo purchase' do
        it 'returns an empty relation' do
          create(:gitlab_subscription_add_on_purchase, tested_add_on_type)

          expect(scope_result).to be_empty
        end
      end
    end

    describe '.for_active_gitlab_duo_purchase' do
      context 'for duo pro add-ons' do
        it_behaves_like 'filters for active gitlab duo purchase' do
          subject(:scope_result) { described_class.for_active_gitlab_duo_purchase }

          let(:tested_add_on_type) { :duo_pro }
        end
      end

      context 'for duo enterprise add-ons' do
        it_behaves_like 'filters for active gitlab duo purchase' do
          subject(:scope_result) { described_class.for_active_gitlab_duo_purchase }

          let(:tested_add_on_type) { :duo_enterprise }
        end
      end
    end

    describe '.for_active_add_on_purchase_ids' do
      context 'when supplied no add on purchase IDs' do
        it 'returns an empty collection' do
          create(:gitlab_subscription_user_add_on_assignment)

          expect(described_class.for_active_add_on_purchase_ids([])).to be_empty
        end
      end

      context 'when the supplied add on purchase IDs have no assignments' do
        it 'returns an empty collection' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase)

          expect(described_class.for_active_add_on_purchase_ids([add_on_purchase.id])).to be_empty
        end
      end

      context 'when the supplied add on purchase IDs do not exist' do
        it 'returns an empty collection' do
          expect(described_class.for_active_add_on_purchase_ids([non_existing_record_id])).to be_empty
        end
      end

      context 'when the supplied add on purchase IDs are for inactive purchases' do
        it 'returns an empty collection' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase, expires_on: 1.week.ago)
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

          expect(described_class.for_active_add_on_purchase_ids([add_on_purchase.id])).to be_empty
        end
      end

      context 'when the supplied add on purchase IDs are for active purchases' do
        it 'returns those assignments' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase)
          assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

          expect(described_class.for_active_add_on_purchase_ids([add_on_purchase.id]))
            .to match_array [assignment]
        end
      end
    end

    describe '.order_by_id_desc' do
      it 'returns assignments ordered by :id in descending order' do
        add_on_purchase = create(:gitlab_subscription_add_on_purchase)

        user_assignment_1 = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)
        user_assignment_2 = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

        expect(described_class.order_by_id_desc).to eq([user_assignment_2, user_assignment_1])
      end
    end
  end

  describe '.pluck_user_ids' do
    it 'plucks the user ids' do
      user = create(:user)
      assignment = create(:gitlab_subscription_user_add_on_assignment, user: user)

      expect(described_class.where(id: assignment).pluck_user_ids).to match_array([user.id])
    end
  end

  it_behaves_like 'a model with paper trail configured' do
    let(:factory) { :gitlab_subscription_user_add_on_assignment }
    let(:attributes_to_update) { { created_at: Time.current } }
    let(:additional_properties) do
      {
        organization_id: object.add_on_purchase.organization_id,
        add_on_name: object.add_on_name,
        user_id: object.user_id,
        namespace_path: object.add_on_purchase.namespace.traversal_path(with_organization: false),
        purchase_id: object.add_on_purchase_id
      }
    end
  end
end
