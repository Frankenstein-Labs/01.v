# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::InitialSetupController, feature_category: :system_access do
  let!(:admin) { create(:admin, username: 'root', password_automatically_set: true) }

  describe '#update' do
    subject(:patch_update) { post :update, params: { user: user_params } }

    context 'with extended auditing enabled' do
      let(:user_params) do
        {
          email: 'capybara@example.com',
          password: 'GiantHamsterD0g!',
          password_confirmation: 'GiantHamsterD0g!'
        }
      end

      before do
        stub_licensed_features(extended_audit_events: true)
      end

      it 'redirects to sign in page' do
        # add email, change primary email, and change password events
        expect { patch_update }.to change { AuditEventReader.count }.by(3)
      end
    end
  end
end
