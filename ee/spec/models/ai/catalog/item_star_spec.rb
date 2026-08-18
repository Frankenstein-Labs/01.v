# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemStar, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:item, freeze: false) { create(:ai_catalog_item, organization: organization) }
  let_it_be(:user_active) { create(:user, state: 'active') }
  let_it_be(:user_blocked) { create(:user, state: 'blocked') }

  describe 'associations' do
    it { is_expected.to belong_to(:item).required }
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:user).required }
  end

  describe 'validations' do
    it 'enforces uniqueness of user_id scoped to ai_catalog_item_id at the database level' do
      create(:ai_catalog_item_star, item: item, user: user_active, organization: organization)

      expect do
        create(:ai_catalog_item_star, item: item, user: user_active, organization: organization)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same user to star different items' do
      other_item = create(:ai_catalog_item, organization: organization)

      create(:ai_catalog_item_star, item: item, user: user_active, organization: organization)
      second_star = build(:ai_catalog_item_star, item: other_item, user: user_active, organization: organization)

      expect(second_star).to be_valid
    end

    it 'is invalid when organization_id does not match the item organization' do
      other_org = create(:organization)
      star = build(:ai_catalog_item_star, item: item, user: user_active, organization: other_org)

      expect(star).not_to be_valid
      expect(star.errors[:organization_id]).to be_present
    end

    it 'is valid when organization_id matches the item organization' do
      star = build(:ai_catalog_item_star, item: item, user: user_active, organization: organization)

      expect(star).to be_valid
    end
  end

  describe '#organization_id' do
    subject { build(:ai_catalog_item_star, :without_organization, item: item, user: user_active) }

    it { is_expected.to populate_sharding_key(:organization_id).with(item.organization_id) }
  end

  describe 'star count hooks' do
    describe 'after_create' do
      it 'increments star_count on the item' do
        expect do
          create(:ai_catalog_item_star, item: item, user: user_active, organization: organization)
        end.to change { item.reload.star_count }.by(1)
      end
    end

    describe 'after_destroy' do
      let_it_be(:star) { create(:ai_catalog_item_star, item: item, user: user_active, organization: organization) }

      before_all { item.update_columns(star_count: 1) }

      it 'decrements star_count on the item' do
        expect { star.destroy! }.to change { item.reload.star_count }.by(-1)
      end
    end
  end
end
