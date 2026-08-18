# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::MinimalAccessProvisioningAlertDismissalsController,
  feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let(:path) { group_minimal_access_provisioning_alert_dismissal_path(group) }

  before_all do
    group.add_owner(owner)
    group.add_developer(developer)
  end

  describe 'POST #create' do
    context 'when signed in as a group owner' do
      before do
        sign_in(owner)
      end

      it 'invokes the dismissal service with the group and returns 200' do
        expect_next_instance_of(
          ::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService,
          current_user: owner, group: group
        ) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(::GitlabSubscriptions::MemberManagement::SeatAwareProvisioning)
          .to receive(:record_group_count_at_dismissal).with(group, owner)

        post path

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'with a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let(:path) { group_minimal_access_provisioning_alert_dismissal_path(subgroup) }

        before_all do
          subgroup.add_owner(owner)
        end

        it 'returns 404 and does not invoke the dismissal service' do
          expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
            .not_to receive(:new)

          post path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when signed in as a non-owner' do
      before do
        sign_in(developer)
      end

      it 'returns 404 and does not invoke the dismissal service' do
        expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
          .not_to receive(:new)

        post path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when not signed in' do
      it 'returns 404 and does not invoke the dismissal service' do
        expect(::GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService)
          .not_to receive(:new)

        post path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
