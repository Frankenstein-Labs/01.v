# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::DesignatedBeneficiary, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }

  it_behaves_like 'having unique enum values'

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:designated_beneficiary, user: user) }

    it { is_expected.to validate_presence_of(:name).with_message('Full name is required') }

    name_too_long_error = 'Full name is too long (maximum is 255 characters)'
    it { is_expected.to validate_length_of(:name).is_at_most(255).with_message(name_too_long_error) }

    it { is_expected.to validate_presence_of(:type) }

    email_too_long_error = 'Email is too long (maximum is 255 characters)'
    it { is_expected.to validate_length_of(:email).is_at_most(255).with_message(email_too_long_error).allow_blank }
    it { is_expected.to allow_value('user@example.com').for(:email) }
    it { is_expected.to allow_value('').for(:email) }
    it { is_expected.to allow_value(nil).for(:email) }
    it { is_expected.not_to allow_value('invalid-email').for(:email) }

    relationship_too_long_error = 'Relationship input is too long (maximum is 255 characters)'
    it { is_expected.to validate_length_of(:relationship).is_at_most(255).with_message(relationship_too_long_error) }

    describe 'relationship validation for successor type' do
      context 'when type is successor' do
        subject { build(:designated_beneficiary, :successor, user: user) }

        it { is_expected.to validate_presence_of(:relationship).with_message('Relationship is required') }
      end

      context 'when type is manager' do
        subject { build(:designated_beneficiary, :manager, user: user) }

        it { is_expected.not_to validate_presence_of(:relationship).with_message('Relationship is required') }
      end
    end

    describe 'uniqueness validation' do
      let_it_be(:existing_manager) { create(:designated_beneficiary, :manager, user: user) }

      context 'when creating another manager for the same user' do
        subject(:manager) { build(:designated_beneficiary, :manager, user: user) }

        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          manager.valid?
          expect(manager.errors[:user_id]).to include(
            'Designated account manager already exists. You can edit or delete in the legacy contacts section below.'
          )
        end
      end

      context 'when creating a successor for the same user' do
        subject { build(:designated_beneficiary, :successor, user: user) }

        it { is_expected.to be_valid }
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:type).with_values(manager: 0, successor: 1) }
  end

  describe 'scopes' do
    let_it_be(:manager) { create(:designated_beneficiary, :manager, user: user) }
    let_it_be(:successor) { create(:designated_beneficiary, :successor, user: user) }

    describe '.manager' do
      it 'returns only manager type records' do
        expect(described_class.manager).to contain_exactly(manager)
      end
    end

    describe '.successor' do
      it 'returns only successor type records' do
        expect(described_class.successor).to contain_exactly(successor)
      end
    end
  end
end
