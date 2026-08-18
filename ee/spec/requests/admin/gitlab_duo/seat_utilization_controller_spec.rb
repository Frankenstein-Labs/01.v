# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuo::SeatUtilizationController, :cloud_licenses, feature_category: :seat_cost_management do
  include AdminModeHelper

  describe 'GET /code_suggestions', :with_cloud_connector do
    let(:plan) { License::STARTER_PLAN }
    let(:license) { build(:license, plan: plan) }

    before do
      allow(License).to receive(:current).and_return(license)
      allow(::Gitlab::Saas).to receive(:feature_available?).and_return(false)
    end

    shared_examples 'renders seat management index page' do
      it 'renders seat management index page' do
        get admin_gitlab_duo_seat_utilization_index_path

        expect(response).to render_template(:index)
        expect(response.body).to include('js-code-suggestions-page')
      end
    end

    shared_examples 'hides seat utilization path' do
      it 'returns 404' do
        get admin_gitlab_duo_seat_utilization_index_path

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).to render_template('errors/not_found')
      end
    end

    shared_examples 'redirects to gitlab duo home path' do
      it 'redirects to gitlab duo home path' do
        get admin_gitlab_duo_seat_utilization_index_path

        expect(response).to redirect_to(admin_gitlab_duo_path)
      end
    end

    context 'when the user is not admin' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'hides seat utilization path'
    end

    context 'when the user is an admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      context 'when instance is self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        context 'when no duo add on is provisioned' do
          it_behaves_like 'redirects to gitlab duo home path'
        end

        context 'with a non seat assignable duo add on' do
          context 'when duo core add on is provisioned' do
            let_it_be(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_core, :active)
            end

            it_behaves_like 'redirects to gitlab duo home path'
          end

          context 'when duo amazon q add on is provisioned' do
            let_it_be(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_amazon_q, :active)
            end

            it_behaves_like 'redirects to gitlab duo home path'
          end
        end

        context 'with a seat assignable duo add on' do
          context 'when duo pro add on is provisioned' do
            let_it_be(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_pro, :active)
            end

            it_behaves_like 'renders seat management index page'
          end

          context 'when duo enterprise add on is provisioned' do
            let_it_be(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise, :active)
            end

            it_behaves_like 'renders seat management index page'
          end
        end
      end

      context 'when instance is SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it_behaves_like 'hides seat utilization path'
      end

      context 'when the instance has a non-paid license' do
        let(:plan) { License::LEGACY_LICENSE_TYPE }

        it_behaves_like 'hides seat utilization path'
      end

      context 'when the instance does not have a license' do
        let(:license) { nil }

        it_behaves_like 'hides seat utilization path'
      end
    end
  end
end
