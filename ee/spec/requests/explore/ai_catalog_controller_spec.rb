# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Explore::AiCatalogController, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  let(:ai_catalog_available) { true }

  describe 'GET #index' do
    let(:path) { explore_ai_catalog_path }

    before do
      allow(Ai::Catalog).to receive(:available?).and_return(ai_catalog_available)
      stub_feature_flags(ai_catalog_public_explore: false)
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      it 'responds with success' do
        get path

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'renders the index template' do
        get path

        expect(response).to render_template('index')
      end

      it 'uses the explore layout' do
        get path

        expect(response).to render_template(layout: 'explore')
      end

      describe 'instance_beta_features_enabled' do
        context 'when user can access experimental and beta features' do
          before do
            allow(Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?)
              .with(user).and_return(true)
          end

          it 'passes instance_beta_features_enabled as true to the frontend' do
            get path

            expect(response.body).to have_css(
              '#js-ai-catalog[data-instance-beta-features-enabled="true"]'
            )
          end
        end

        context 'when user cannot access experimental and beta features' do
          before do
            allow(Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?)
              .with(user).and_return(false)
          end

          it 'passes instance_beta_features_enabled as false to the frontend' do
            get path

            expect(response.body).to have_css(
              '#js-ai-catalog[data-instance-beta-features-enabled="false"]'
            )
          end
        end
      end

      context 'when AI Catalog is not available for the instance' do
        let(:ai_catalog_available) { false }

        it 'renders 404' do
          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not signed in' do
      it 'redirects to login page' do
        get path

        expect(response).to redirect_to new_user_session_path
      end

      context 'when ai_catalog_public_explore feature flag is enabled' do
        before do
          stub_feature_flags(ai_catalog_public_explore: true)
          allow(Ai::Catalog).to receive(:feature_available?).and_return(true)
        end

        it 'responds with success' do
          get path

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'renders the index template' do
          get path

          expect(response).to render_template('index')
        end

        it 'passes instance_beta_features_enabled as false to the frontend' do
          get path

          expect(response.body).to have_css(
            '#js-ai-catalog[data-instance-beta-features-enabled="false"]'
          )
        end

        context 'when AI Catalog feature is not available' do
          before do
            allow(Ai::Catalog).to receive(:feature_available?).and_return(false)
          end

          it 'renders 404' do
            get path

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
