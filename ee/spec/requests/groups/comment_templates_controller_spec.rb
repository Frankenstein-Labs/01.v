# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::CommentTemplatesController, feature_category: :code_review_workflow do
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:user) { create(:user) }

  context 'without permission' do
    describe 'GET #index' do
      context 'when license is invalid' do
        before do
          stub_licensed_features(group_saved_replies: false)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:not_found) }
      end

      context 'when license is valid' do
        before do
          stub_licensed_features(group_saved_replies: true)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:not_found) }
      end
    end
  end

  context 'as developer' do
    before_all do
      group.add_developer(user)
    end

    before do
      sign_in(user)
    end

    describe 'GET #index' do
      context 'when license is invalid' do
        before do
          stub_licensed_features(group_saved_replies: false)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:not_found) }
      end

      context 'when license is valid' do
        before do
          stub_licensed_features(group_saved_replies: true)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:ok) }
      end
    end
  end

  context 'as owner' do
    before_all do
      group.add_owner(user)
    end

    before do
      sign_in(user)
    end

    describe 'GET #index' do
      context 'when license is invalid' do
        before do
          stub_licensed_features(group_saved_replies: false)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:not_found) }
      end

      context 'when license is valid' do
        before do
          stub_licensed_features(group_saved_replies: true)

          get group_comment_templates_path(group)
        end

        it { expect(response).to have_gitlab_http_status(:ok) }
      end
    end
  end
end
