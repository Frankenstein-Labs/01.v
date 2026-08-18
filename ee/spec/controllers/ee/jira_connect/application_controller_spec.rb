# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JiraConnect::ApplicationController, feature_category: :team_planning do
  describe 'before_actions' do
    describe '#check_if_blocked_by_settings' do
      controller do
        skip_before_action :verify_atlassian_jwt!

        def index
          head :ok
        end
      end

      it 'allows the request when Jira app is not blocked by settings' do
        get :index

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 404 when Jira app is blocked by settings' do
        allow(Integrations::JiraCloudApp).to receive(:blocked_by_settings?).and_return(true)

        get :index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
