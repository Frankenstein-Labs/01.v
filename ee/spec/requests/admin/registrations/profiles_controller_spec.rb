# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Registrations::ProfilesController, feature_category: :onboarding do
  let_it_be(:admin) { create(:admin) }

  describe 'GET /admin/registrations/profile/new' do
    subject(:get_new) { get new_admin_registrations_profile_path }

    context 'when on SaaS' do
      before do
        stub_saas_features(subscriptions_trials: true)
        sign_in(admin)
      end

      it 'returns not found', :enable_admin_mode do
        get_new

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when not on SaaS' do
      before do
        stub_saas_features(subscriptions_trials: false)
        sign_in(admin)
      end

      it 'returns ok', :enable_admin_mode do
        get_new

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'defaults the email opt-in checkbox to checked', :enable_admin_mode do
        get_new

        expect(response.body).to have_checked_field(
          'I agree that GitLab can contact me by email about its product, services, or events.'
        )
      end
    end
  end

  describe 'PATCH /admin/registrations/profile' do
    let(:user_params) do
      {
        first_name: 'Jane',
        last_name: 'Doe',
        email: admin.email,
        user_detail_attributes: {
          company: 'Acme Corp',
          onboarding_status_country: 'US',
          onboarding_status_email_opt_in: '1'
        }
      }
    end

    subject(:patch_update) { patch admin_registrations_profile_path, params: { user: user_params } }

    context 'with an admin user on SM', :enable_admin_mode do
      before do
        stub_saas_features(subscriptions_trials: false)
        sign_in(admin)
      end

      it 'persists the country to onboarding_status' do
        expect { patch_update }
          .to change { admin.reload.user_detail.onboarding_status_country }.to('US')
      end

      it 'persists the email opt-in to onboarding_status' do
        expect { patch_update }
          .to change { admin.reload.user_detail.onboarding_status_email_opt_in }.to(true)
      end

      context 'when opt-in is true and no trial license' do
        it 'enqueues the product interaction worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .to receive(:perform_async).with(admin.id)

          patch_update
        end
      end

      context 'when no license is installed (Free SM instance)' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'enqueues the product interaction worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .to receive(:perform_async).with(admin.id)

          patch_update
        end
      end

      context 'when opt-in is false' do
        let(:user_params) do
          {
            first_name: 'Jane', last_name: 'Doe', email: admin.email,
            user_detail_attributes: {
              company: 'Acme Corp',
              onboarding_status_country: 'US',
              onboarding_status_email_opt_in: '0'
            }
          }
        end

        it 'does not enqueue the product interaction worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .not_to receive(:perform_async)

          patch_update
        end
      end

      context 'when on a trial license' do
        before do
          allow(License).to receive(:current).and_wrap_original do |method|
            license = method.call
            allow(license).to receive(:trial?).and_return(true) if license
            license || instance_double(License, trial?: true, feature_available?: true)
          end
        end

        it 'does not enqueue the product interaction worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .not_to receive(:perform_async)

          patch_update
        end
      end

      context 'when running on SaaS' do
        before do
          stub_saas_features(subscriptions_trials: true)
        end

        it 'returns not found and does not enqueue the worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .not_to receive(:perform_async)

          patch_update

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the update fails' do
        before do
          allow_next_instance_of(::Users::UpdateService) do |service|
            allow(service).to receive(:execute).and_return({ status: :error, message: 'invalid' })
          end
        end

        it 'does not enqueue the worker' do
          expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker)
            .not_to receive(:perform_async)

          patch_update
        end
      end
    end
  end
end
