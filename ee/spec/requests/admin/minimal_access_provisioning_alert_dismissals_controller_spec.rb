# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::MinimalAccessProvisioningAlertDismissalsController,
  feature_category: :seat_cost_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  let(:path) { admin_minimal_access_provisioning_alert_dismissal_path }

  describe 'POST #create' do
    context 'when signed in as an admin in admin mode', :enable_admin_mode do
      before do
        sign_in(admin)
      end

      it 'invokes the dismissal service and returns 200' do
        expect_next_instance_of(
          ::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService,
          current_user: admin
        ) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(::GitlabSubscriptions::MemberManagement::SeatAwareProvisioning)
          .to receive(:record_instance_count_at_dismissal).with(admin)

        post path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when signed in as an admin without admin mode' do
      before do
        sign_in(admin)
      end

      it 'does not invoke the dismissal service' do
        expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
          .not_to receive(:new)

        post path

        expect(response).not_to have_gitlab_http_status(:ok)
      end
    end

    context 'when signed in as a non-admin' do
      before do
        sign_in(user)
      end

      it 'does not invoke the dismissal service' do
        expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
          .not_to receive(:new)

        post path

        expect(response).not_to have_gitlab_http_status(:ok)
      end
    end

    context 'when not signed in' do
      it 'does not invoke the dismissal service' do
        expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
          .not_to receive(:new)

        post path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end
  end
end
