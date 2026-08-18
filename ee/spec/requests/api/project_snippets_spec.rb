# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectSnippets, feature_category: :source_code_management do
  include SnippetHelpers

  let_it_be(:project) { create(:project, :public) }

  describe 'POST /projects/:project_id/snippets/' do
    let(:base_params) do
      {
        title: 'Test Title',
        description: 'test description',
        visibility: 'public'
      }
    end

    let(:file_path) { 'file_1.rb' }
    let(:file_content) { 'example content' }
    let(:file_params) { { files: [{ file_path: file_path, content: file_content }] } }

    subject(:request) { post api("/projects/#{project.id}/snippets/", user), params: base_params.merge(file_params) }

    context 'with an enterprise user with allow_personal_snippets: false' do
      let_it_be(:enterprise_group) { create(:group).tap { |group| group.update!(allow_personal_snippets: false) } }
      let_it_be(:user) { create(:user, enterprise_group: enterprise_group) }

      before_all do
        project.add_developer(user)
      end

      before do
        stub_licensed_features(allow_personal_snippets: true)
        stub_saas_features(allow_personal_snippets: true)
      end

      it 'project snippets are unaffected' do
        request

        expect(response).to have_gitlab_http_status(:created)
      end
    end
  end
end
