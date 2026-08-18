# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin GitLab Duo home page', feature_category: :ai_abstraction_layer do
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- admin page reads instance AI settings stored on the default organization
  let_it_be(:admin) { create(:admin) }

  describe 'code suggestions usage' do
    context 'when saas', :saas, :js do
      before do
        create(:gitlab_subscription_add_on_purchase, :duo_pro)
        sign_in(admin)
        enable_admin_mode!(admin)

        visit admin_gitlab_duo_path
      end

      it 'does not render Duo configuration info card' do
        expect(page).not_to have_content('GitLab Duo Pro')
        expect(page).not_to have_selector('[data-testid="duo-configuration-settings-info-card"]')
      end

      it 'does not render Duo seat utilization info card' do
        expect(page).not_to have_content('Seat utilization')
        expect(page).not_to have_selector('[data-testid="duo-seat-utilization-info-card"]')
      end
    end

    context 'when self-managed', :js do
      before do
        status_service = instance_double(::CloudConnector::StatusChecks::StatusService)
        allow(::CloudConnector::StatusChecks::StatusService).to receive(:new).and_return(status_service)
        allow(status_service).to receive(:execute).and_return(ServiceResponse.success)

        # Stub the model definitions service to avoid real HTTP requests
        allow(::Ai::ModelSelection::FetchModelDefinitionsService)
          .to receive(:new).and_return(
            instance_double(
              ::Ai::ModelSelection::FetchModelDefinitionsService,
              execute: ServiceResponse.success(payload: { 'models' => [], 'unit_primitives' => [] })
            )
          )

        sign_in(admin)
        enable_admin_mode!(admin)
      end

      context 'when duo tier is not Duo Core' do
        before do
          create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_pro)
        end

        it 'renders Duo seat utilization info card' do
          visit admin_gitlab_duo_path

          expect(page).to have_content('Seat utilization')
          expect(page).to have_selector('[data-testid="duo-seat-utilization-info-card"]')
        end

        it 'renders Duo configuration info card' do
          visit admin_gitlab_duo_path

          expect(page).to have_content('GitLab Duo Pro')
          expect(page).to have_selector('[data-testid="duo-configuration-settings-info-card"]')
        end
      end

      context 'when tier is Duo Core' do
        before do
          create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_core)
        end

        it 'does not render Duo seat utilization info card' do
          visit admin_gitlab_duo_path

          expect(page).not_to have_content('Seat utilization')
          expect(page).not_to have_selector('[data-testid="duo-seat-utilization-info-card"]')
        end

        it 'renders Duo configuration info card' do
          visit admin_gitlab_duo_path

          expect(page).to have_content('GitLab Duo Core')
          expect(page).to have_selector('[data-testid="duo-configuration-settings-info-card"]')
        end
      end
    end
  end
end
