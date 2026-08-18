# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessage, feature_category: :acquisition do
  describe 'validations' do
    subject(:targeted_message) { build(:targeted_message) }

    it { is_expected.to validate_presence_of(:target_type) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:ends_at) }
    it { is_expected.to validate_inclusion_of(:roles).in_array(Notifications::TargetedMessage::ALLOWED_ROLES) }

    context 'with targeted_message_namespaces validation' do
      it 'is invalid without any namespaces' do
        targeted_message.targeted_message_namespaces.clear
        expect(targeted_message).not_to be_valid
      end

      it 'is valid with at least one namespace' do
        expect(targeted_message).to be_valid
      end
    end

    describe 'starts_at_before_ends_at' do
      it 'is valid when starts_at is before ends_at' do
        message = build(:targeted_message, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        expect(message).to be_valid
      end

      it 'is invalid when starts_at is equal to ends_at' do
        time = 1.hour.from_now
        message = build(:targeted_message, starts_at: time, ends_at: time)
        expect(message).to be_invalid
        expect(message.errors[:starts_at]).to include('must be before ends at')
      end

      it 'is invalid when starts_at is after ends_at' do
        message = build(:targeted_message, starts_at: 2.hours.from_now, ends_at: 1.hour.from_now)
        expect(message).to be_invalid
        expect(message.errors[:starts_at]).to include('must be before ends at')
      end
    end

    describe 'starts_at_not_in_past' do
      it 'is valid when starts_at is in the future' do
        message = build(:targeted_message, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        expect(message).to be_valid
      end

      it 'is invalid when starts_at is in the past' do
        message = build(:targeted_message, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        expect(message).to be_invalid
        expect(message.errors[:starts_at]).to include('cannot be in the past')
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:targeted_message_namespaces) }
    it { is_expected.to have_many(:targeted_message_dismissals) }
    it { is_expected.to have_many(:namespaces).through(:targeted_message_namespaces) }

    describe 'dependent destroy' do
      let_it_be(:user) { create(:user) }
      let_it_be(:targeted_message) { create(:targeted_message) }
      let_it_be(:dismissal) do
        create(:targeted_message_dismissal, targeted_message_id: targeted_message.id,
          namespace: targeted_message.namespaces.take, user: user)
      end

      it 'destroys associated targeted_message_namespaces and targeted_message_dismissals when message is destroyed' do
        expect { targeted_message.destroy! }
          .to change { Notifications::TargetedMessageNamespace.count }.by(-1)
          .and change { Notifications::TargetedMessageDismissal.count }.by(-1)
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:target_type) }

    it_behaves_like 'having unique enum values'
  end

  describe '#matches_current_user_access_level?' do
    context 'when roles is empty' do
      let(:targeted_message) { build(:targeted_message) }

      it 'returns true for any access level' do
        expect(targeted_message.matches_current_user_access_level?(Gitlab::Access::GUEST)).to be(true)
        expect(targeted_message.matches_current_user_access_level?(nil)).to be(true)
      end
    end

    context 'when roles are set' do
      let(:targeted_message) do
        build(:targeted_message, roles: [Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER])
      end

      it 'returns true when user access level matches' do
        expect(targeted_message.matches_current_user_access_level?(Gitlab::Access::GUEST)).to be(false)
        expect(targeted_message.matches_current_user_access_level?(Gitlab::Access::MAINTAINER)).to be(true)
      end
    end
  end
end
