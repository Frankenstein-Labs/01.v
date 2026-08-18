# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SetUserStatusBasedOnUserCapSettingWorker, type: :worker, feature_category: :user_profile do
  describe '#perform' do
    let_it_be(:active_user) { create(:user, state: 'active') }
    let_it_be(:active_admin) { create(:user, :admin, state: 'active') }
    let_it_be(:inactive_admin) { create(:user, :admin, :deactivated) }
    let_it_be(:user) { create(:user, :blocked_pending_approval) }

    subject { described_class.new.perform(user.id) }

    before do
      allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
      stub_application_setting(seat_control: seat_control)
    end

    shared_examples 'sends emails to every active admin' do
      it 'sends an email to every active admin' do
        expect(::Notify).to receive(:user_cap_reached).with(active_admin.id).once.and_call_original

        subject
      end
    end

    shared_examples 'does not send emails to active admins' do
      it 'does not send an email to active admins' do
        expect(::Notify).not_to receive(:user_cap_reached)

        subject
      end
    end

    context 'when user cap is set to nil' do
      let(:new_user_signups_cap) { nil }
      let(:seat_control) { 0 }

      include_examples 'does not send emails to active admins'
    end

    context 'when current billable user count is less than user cap' do
      let(:new_user_signups_cap) { 10 }
      let(:seat_control) { 1 }

      include_examples 'does not send emails to active admins'
    end

    context 'when current billable user count is equal to user cap' do
      let(:new_user_signups_cap) { 2 }
      let(:seat_control) { 1 }

      include_examples 'sends emails to every active admin'
    end

    context 'when current billable user count is greater than user cap' do
      let(:new_user_signups_cap) { 1 }
      let(:seat_control) { 1 }

      include_examples 'sends emails to every active admin'

      context 'when the auto-creation of an omniauth user is blocked' do
        before do
          allow(Gitlab.config.omniauth).to receive(:block_auto_created_users).and_return(true)
        end

        context 'when the user is an omniauth user' do
          let!(:user) { create(:omniauth_user, :blocked_pending_approval) }

          include_examples 'does not send emails to active admins'
        end
      end
    end
  end
end
