# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DashboardController, feature_category: :notifications do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  context 'signed in' do
    before do
      sign_in(user)
    end

    describe 'GET issues', feature_category: :team_planning do
      it 'redirects to work items dashboard' do
        get :issues

        expect(response).to have_gitlab_http_status(:moved_permanently)
      end
    end
  end
end
