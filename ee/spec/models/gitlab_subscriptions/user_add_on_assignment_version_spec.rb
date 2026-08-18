# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignmentVersion, feature_category: :seat_cost_management do
  it "includes PaperTrail::VersionConcern" do
    expect(described_class).to include(PaperTrail::VersionConcern)
  end

  it "includes EachBatch" do
    expect(described_class).to include(EachBatch)
  end

  describe '.for_add_on_purchases' do
    let_it_be(:namespace_1) { create(:group) }
    let_it_be(:namespace_2) { create(:group) }
    let_it_be(:add_on_1) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:add_on_2) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:add_on_purchase_1) do
      create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on_1, namespace: namespace_1)
    end

    let_it_be(:add_on_purchase_2) do
      create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on_2, namespace: namespace_2)
    end

    let_it_be(:user_1) { create(:user) }
    let_it_be(:user_2) { create(:user) }

    let_it_be(:assignment_1) do
      create(:gitlab_subscription_user_add_on_assignment, user: user_1, add_on_purchase: add_on_purchase_1)
    end

    let_it_be(:assignment_2) do
      create(:gitlab_subscription_user_add_on_assignment, user: user_2, add_on_purchase: add_on_purchase_2)
    end

    it 'returns versions for the specified add-on purchases' do
      versions = described_class.for_add_on_purchases(
        GitlabSubscriptions::AddOnPurchase.where(id: add_on_purchase_1.id))

      expect(versions.pluck(:purchase_id)).to contain_exactly(add_on_purchase_1.id)
    end

    it 'returns versions for multiple add-on purchases' do
      versions = described_class.for_add_on_purchases(
        GitlabSubscriptions::AddOnPurchase.where(id: [add_on_purchase_1.id, add_on_purchase_2.id]))

      expect(versions.pluck(:purchase_id)).to contain_exactly(add_on_purchase_1.id, add_on_purchase_2.id)
    end

    it 'returns empty relation when no matching purchases' do
      versions = described_class.for_add_on_purchases(
        GitlabSubscriptions::AddOnPurchase.where(id: non_existing_record_id))

      expect(versions).to be_empty
    end
  end
end
