# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::ContinuousDeploymentController, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  shared_examples 'continuous deployment show action' do
    context 'when the user is not signed in' do
      it_behaves_like 'organization - redirects to sign in page'
    end

    context 'when the user is signed in' do
      before do
        sign_in(user)
      end

      context 'when the `ai_native_deploy` feature flag is enabled' do
        it_behaves_like 'organization - successful response'
      end

      context 'when the `ai_native_deploy` feature flag is disabled' do
        before do
          stub_feature_flags(ai_native_deploy: false)
        end

        it_behaves_like 'organization - not found response'
      end
    end
  end

  describe 'GET #show' do
    context 'with the deploy route' do
      subject(:gitlab_request) { get deploy_organization_path(organization) }

      it_behaves_like 'continuous deployment show action'
    end

    context 'with the deploy applications route' do
      subject(:gitlab_request) { get deploy_applications_organization_path(organization) }

      it_behaves_like 'continuous deployment show action'
    end

    context 'with the deploy environments route' do
      subject(:gitlab_request) { get deploy_environments_organization_path(organization) }

      it_behaves_like 'continuous deployment show action'
    end
  end
end
