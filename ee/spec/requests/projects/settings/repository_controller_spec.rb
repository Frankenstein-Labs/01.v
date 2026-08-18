# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::RepositoryController, feature_category: :source_code_management do
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project_empty_repo, :public, namespace: group) }

  before_all do
    project.add_developer(developer)
    project.add_maintainer(maintainer)
  end

  before do
    sign_in(user)
  end

  describe 'GET show' do
    subject(:get_show) do
      get project_settings_repository_path(project)
    end

    context 'as a developer' do
      let(:user) { developer }

      it 'renders a 404 page' do
        get_show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'as a maintainer' do
      let(:user) { maintainer }

      context 'with protected branches and tags' do
        it 'does not cause a N+1 problem' do
          create_list(:protected_branch, 3, project: project)
          create_list(:protected_tag, 3, project: project)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get_show }

          expect(control.log).to include(/SELECT "protected_branch_merge_access_levels"/).once
          expect(control.log).to include(/SELECT "protected_branch_push_access_levels"/).once
          expect(control.log).to include(/SELECT "protected_tag_create_access_levels"/).once

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end
      end

      context 'with custom roles' do
        before do
          stub_licensed_features(custom_roles: true)

          # TODO: reduce query for Duo permission check
          # https://gitlab.com/gitlab-org/gitlab/-/work_items/588899
          stub_ee_application_setting(duo_features_enabled: false, lock_duo_features_enabled: true)
        end

        it 'does not cause a N+1 problem' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get_show }

          expect(control).not_to exceed_query_limit(89).allow_skip_cache_inconsistency
          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end
      end
    end
  end
end
