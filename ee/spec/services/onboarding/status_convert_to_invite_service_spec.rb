# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusConvertToInviteService, feature_category: :onboarding do
  describe '#execute' do
    let_it_be(:original_registration_type) { 'free' }
    let_it_be_with_reload(:user) do
      create(:user, onboarding_in_progress: true, onboarding_status_registration_type: original_registration_type)
    end

    let(:updated_registration_type) { 'invite' }

    subject(:execute) { described_class.new(user).execute }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when update is successful' do
        it 'updates onboarding_status_registration_type' do
          expect { execute }.to change { user.onboarding_status_registration_type }.to(updated_registration_type)
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_success
          expect(execute[:user].onboarding_status_registration_type).to eq(updated_registration_type)
          expect(execute[:user].onboarding_status_initial_registration_type).to be_nil
        end

        context 'when initial registration type is changed also' do
          subject(:execute) { described_class.new(user, initial_registration: true).execute }

          it 'updates both onboarding_status registration types' do
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_success
            expect(execute[:user].onboarding_status_registration_type).to eq(updated_registration_type)
            expect(execute[:user].onboarding_status_initial_registration_type).to eq(updated_registration_type)
          end
        end
      end

      context 'when update is not successful due to systemic failure' do
        before do
          allow(user).to receive(:update).and_return(false)
        end

        it 'does not update the onboarding_status_registration_type' do
          expect(execute[:user].onboarding_status_registration_type).to eq(original_registration_type)
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_error
        end
      end
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect { execute }.not_to change { user.reset.onboarding_status_registration_type }
      end
    end
  end
end
