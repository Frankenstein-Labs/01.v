# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuo::ConfigurationController, :cloud_licenses, feature_category: :ai_abstraction_layer do
  include AdminModeHelper

  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- admin page reads instance AI settings stored on the default organization

  subject(:get_index) { get admin_gitlab_duo_configuration_index_path }

  describe 'GET /admin/gitlab_duo/configuration' do
    let(:plan) { License::STARTER_PLAN }
    let(:license) { build(:license, plan: plan) }

    let!(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed, :active) }

    before do
      allow(License).to receive(:current).and_return(license)

      stub_saas_features(gitlab_com_subscriptions: false)

      allow_next_instance_of(::Ai::UsageQuotaService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    shared_examples 'redirects configuration path' do
      it 'redirects to admin_gitlab_duo_path' do
        get_index

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(admin_gitlab_duo_path)
      end
    end

    shared_examples 'renders duo settings form' do
      it 'renders duo settings form' do
        get_index

        expect(response).to render_template(:index)
        expect(response.body).to include('js-ai-settings')
      end
    end

    context 'when the user is not admin' do
      before do
        sign_in create(:user)
      end

      it 'returns 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).to render_template('errors/not_found')
      end
    end

    context 'when the user is an admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      it_behaves_like 'renders duo settings form'

      context 'when the instance has a self-hosted DAP add-on' do
        let!(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_hosted_dap, :self_managed, :active)
        end

        before do
          # Rendering this page will have the chat window available, which makes a usage quota call
          allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
            allow(instance).to receive_messages(
              show_duo_entry_point?: true,
              enabled_for_container?: true,
              agentic_mode_available?: false,
              classic_chat_available?: false,
              credits_available?: true,
              chat_disabled_reason: nil
            )
          end
        end

        it_behaves_like 'renders duo settings form'
      end

      context 'when instance is SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance does not have a Duo add-on purchase' do
        let(:add_on_purchase) { nil }

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance has a non-paid license' do
        let(:plan) { License::LEGACY_LICENSE_TYPE }

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance does not have a license' do
        let(:license) { nil }

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance has an active gitlab_credits add-on' do
        let(:add_on_purchase) { nil }
        let!(:credits_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :self_managed, :active)
        end

        it_behaves_like 'renders duo settings form'

        context 'when the instance does not have a license' do
          let(:license) { nil }

          it_behaves_like 'renders duo settings form'
        end
      end
    end
  end
end
