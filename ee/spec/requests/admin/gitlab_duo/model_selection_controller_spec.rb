# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuo::ModelSelectionController, :enable_admin_mode, feature_category: :"self-hosted_models" do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'returns successful response' do
    it 'returns 200' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  shared_examples 'returns not found' do
    it 'returns 404' do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    let(:page) { Nokogiri::HTML(response.body) }

    subject :perform_request do
      get admin_gitlab_duo_model_selection_index_path
    end

    context 'when user can manage self hosted models settings' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_self_hosted_models_settings, anything).and_return(true)
      end

      it_behaves_like 'returns successful response'
    end

    context 'when user can manage instance model selection' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_instance_model_selection, anything).and_return(true)
      end

      it_behaves_like 'returns successful response'
    end

    context 'when the user is not authorized' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_self_hosted_models_settings, anything).and_return(false)
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_instance_model_selection, anything).and_return(false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when on GitLab.com (SaaS)' do
      before do
        allow(::Gitlab::Saas).to receive(:feature_available?).and_call_original
        allow(::Gitlab::Saas).to receive(:feature_available?)
          .with(:gitlab_com_subscriptions).and_return(true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_self_hosted_models_settings, anything).and_return(true)
      end

      it_behaves_like 'returns not found'

      context 'when accessing a model management vueroute' do
        subject(:perform_request) { get "/admin/gitlab_duo/model_selection/models/new" }

        it_behaves_like 'returns not found'
      end
    end
  end

  context 'when accessing model management routes' do
    subject(:perform_request) { get "/admin/gitlab_duo/model_selection/#{vueroute}" }

    context 'when vueroute is nil' do
      let(:vueroute) { nil }

      it_behaves_like 'returns successful response'
    end

    context 'when vueroute is empty' do
      let(:vueroute) { '' }

      it_behaves_like 'returns successful response'
    end

    context 'with manage_self_hosted_models_settings permission' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_self_hosted_models_settings, anything).and_return(true)
      end

      context 'when accessing models/new' do
        let(:vueroute) { 'models/new' }

        it_behaves_like 'returns successful response'
      end

      context 'when accessing models/:id/edit' do
        let(:vueroute) { 'models/123/edit' }

        it_behaves_like 'returns successful response'
      end
    end

    context 'without manage_self_hosted_models_settings permission' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin,
          :manage_self_hosted_models_settings, anything).and_return(false)
      end

      context 'when accessing models/new' do
        let(:vueroute) { 'models/new' }

        it_behaves_like 'returns not found'
      end

      context 'when accessing models/:id/edit' do
        let(:vueroute) { 'models/456/edit' }

        it_behaves_like 'returns not found'
      end
    end
  end
end
