# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CommitController, feature_category: :source_code_management do
  let_it_be(:project)  { create(:project, :small_repo) }
  let_it_be(:user)     { create(:user) }

  let(:commit) { project.commit("master") }

  before_all do
    project.add_maintainer(user)
  end

  describe 'GET show' do
    before do
      sign_in(user)
    end

    def go(extra_params = {})
      params = {
        namespace_id: project.namespace,
        project_id: project
      }

      get :show, params: params.merge(extra_params)
    end

    it 'sets the ApplicationContext with an ai_resource key' do
      go(id: commit.id)

      expect(Gitlab::ApplicationContext.current).to include('meta.ai_resource' => commit.try(:to_global_id))
    end
  end
end
