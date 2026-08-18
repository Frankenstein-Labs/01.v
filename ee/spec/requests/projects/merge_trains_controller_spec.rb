# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MergeTrainsController, type: :request, feature_category: :merge_trains do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  describe 'GET /:namespace/:project/-/merge_trains' do
    subject(:request) { get project_merge_trains_url(project) }

    before_all do
      project.add_maintainer(user)
    end

    context 'when feature is enabled' do
      before do
        stub_licensed_features(merge_trains: true)
        sign_in(user)

        request
      end

      it 'renders the merge trains index template' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template('projects/merge_trains/index')
      end
    end

    context 'when feature is disabled' do
      before do
        stub_licensed_features(merge_trains: false)
        sign_in(user)

        request
      end

      it 'returns "not found response"' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
