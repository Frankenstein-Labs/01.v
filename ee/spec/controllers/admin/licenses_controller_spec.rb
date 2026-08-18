# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::LicensesController, feature_category: :plan_provisioning do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe 'Upload license' do
    render_views

    it 'redirects with an alert when entered/uploaded license is invalid' do
      expect do
        post :create, params: { license: { data: 'GA!89-)GaRBAGE' } }
      end.not_to change { License.count }

      expect(response).to redirect_to general_admin_application_settings_path
      expect(flash[:alert]).to include(
        _('The license key is invalid. Make sure it is exactly as you received it from GitLab Inc.')
      )
    end

    it 'redirects to the subscription page when entered/uploaded license is valid' do
      gl_license = build(
        :gitlab_license,
        :legacy,
        restrictions: {
          trial: false,
          plan: License::PREMIUM_PLAN,
          active_user_count: 1,
          previous_user_count: 1
        }
      )
      license = build(:license, data: gl_license.export)

      expect do
        post :create, params: { license: { data: license.data } }
      end.to change { License.count }.by(1)

      expect(response).to redirect_to(admin_subscription_path)
      expect(flash[:notice]).to include(
        _('The license was successfully uploaded and is now active. You can see the details below.')
      )
    end
  end

  describe 'POST sync_seat_link' do
    let_it_be(:historical_data) { create(:historical_data, recorded_at: Time.current) }

    before do
      allow(License).to receive(:current).and_return(create(:license, cloud: cloud_license_enabled))
    end

    context 'with a cloud license' do
      let(:cloud_license_enabled) { true }

      it 'returns a success response' do
        post :sync_seat_link, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end
    end

    context 'without a cloud license' do
      let(:cloud_license_enabled) { false }

      it 'returns a failure response' do
        post :sync_seat_link, format: :json

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response).to eq({ 'success' => false })
      end
    end
  end

  describe 'DELETE destroy' do
    let(:cloud_licenses) { License.where(cloud: true) }

    before do
      allow(License).to receive(:current).and_return(create(:license, cloud: is_cloud_license))
    end

    shared_examples 'license removal' do
      it 'removes the license' do
        delete :destroy, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
        expect(flash[:notice]).to match('The license was removed. GitLab has fallen back on the previous license.')
        expect(cloud_licenses).to be_empty
      end
    end

    context 'with a cloud license' do
      let(:is_cloud_license) { true }

      it_behaves_like 'license removal'
    end

    context 'with a legacy license' do
      let(:is_cloud_license) { false }

      it_behaves_like 'license removal'
    end
  end
end
