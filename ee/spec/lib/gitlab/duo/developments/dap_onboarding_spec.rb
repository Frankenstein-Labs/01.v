# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::DapOnboarding, :silence_stdout, feature_category: :duo_chat do
  describe '.execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:admin_user) { create(:admin, username: 'root') }
    let(:onboarding_service) { instance_double(::Ai::DuoWorkflows::OnboardingService) }
    let(:result) { ServiceResponse.success(message: 'Success') }

    before do
      allow(User).to receive(:find_by_username).with('root').and_return(admin_user)
      allow(admin_user).to receive(:can_admin_all_resources?).and_return(true)
      allow(::Organizations::Organization).to receive(:find_by_id).with(1).and_return(organization)
      allow(::Ai::DuoWorkflows::OnboardingService).to receive(:new)
       .with(current_user: admin_user, organization: organization)
       .and_return(onboarding_service)
      allow(onboarding_service).to receive(:execute).and_return(result)
    end

    it 'calls the onboarding service' do
      described_class.execute

      expect(::Ai::DuoWorkflows::OnboardingService).to have_received(:new)
        .with(current_user: admin_user, organization: organization)
      expect(onboarding_service).to have_received(:execute)
    end

    it 'prints success message when onboarding succeeds' do
      expect { described_class.execute }.to output(/Duo Agent Platform onboarded successfully/).to_stdout
    end

    context 'when onboarding fails' do
      let(:result) { ServiceResponse.error(message: 'Something went wrong!') }

      it 'prints failure message' do
        expect { described_class.execute }.to output(/Onboarding failed: Something went wrong!/).to_stdout
      end
    end

    context 'when root user does not exist' do
      before do
        allow(User).to receive(:find_by_username).with('root').and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.execute }.to raise_error('Please ensure an admin user exists.')
      end
    end

    context 'when root user is not an admin' do
      let(:non_admin_user) { create(:user, username: 'regular_user') }

      before do
        allow(User).to receive(:find_by_username).with('root').and_return(non_admin_user)
        allow(non_admin_user).to receive(:can_admin_all_resources?).and_return(false)
      end

      it 'raises an error' do
        expect { described_class.execute }.to raise_error('Please ensure an admin user exists.')
      end
    end
  end
end
