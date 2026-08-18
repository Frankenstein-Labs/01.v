# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl,
  feature_category: :compliance_management do
  describe ".user_subject_to_pipl?" do
    let_it_be(:user) { create(:user) }

    subject(:user_subject_to_pipl) { described_class.user_subject_to_pipl?(user) }

    context 'when there is no user' do
      let(:user) { nil }

      it 'returns false' do
        expect(user_subject_to_pipl).to be(false)
      end
    end

    context 'when there is no pipl user' do
      it 'returns false' do
        expect(user_subject_to_pipl).to be(false)
      end
    end

    context 'when the user is cached' do
      let_it_be(:pipl_user) { create(:pipl_user, initial_email_sent_at: 20.days.ago, user: user) }

      before do
        allow(Rails.cache).to receive(:read)
                                .with([ComplianceManagement::Pipl::PIPL_SUBJECT_USER_CACHE_KEY, user.id])
                                .and_return(true)
      end

      it 'is subject to pipl' do
        expect(user_subject_to_pipl).to be(true)
      end
    end

    context 'when the user is not cached' do
      before do
        allow(Rails.cache).to receive(:read)
                                .with([ComplianceManagement::Pipl::PIPL_SUBJECT_USER_CACHE_KEY, user.id])
                                .and_return(nil)
      end

      it 'is not subject to pipl' do
        expect(user_subject_to_pipl).to be(false)
      end
    end
  end
end
