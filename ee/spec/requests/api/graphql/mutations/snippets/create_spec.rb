# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a Snippet', feature_category: :source_code_management do
  include GraphqlHelpers

  let(:title) { 'Initial title' }
  let(:visibility_level) { 'public' }
  let(:action) { :create }
  let(:file) { { filePath: 'example_file1', content: 'example content' } }
  let(:actions) { [{ action: action }.merge(file)] }
  let(:project_path) { nil }
  let(:mutation_vars) do
    {
      visibility_level: visibility_level,
      title: title,
      project_path: project_path,
      blob_actions: actions
    }
  end

  let(:mutation) do
    graphql_mutation(:create_snippet, mutation_vars)
  end

  subject(:create_snippet) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'with an enterprise group' do
    let_it_be(:enterprise_group) { create(:group).tap { |group| group.update!(allow_personal_snippets: false) } }
    let_it_be(:current_user) { create(:user, enterprise_group: enterprise_group) }

    context 'with PersonalSnippet' do
      context 'with an enterprise user with allow_personal_snippets: false' do
        before do
          stub_licensed_features(allow_personal_snippets: true)
          stub_saas_features(allow_personal_snippets: true)
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end
    end

    context 'with ProjectSnippet' do
      let_it_be(:project) { create(:project) }
      let(:project_path) { project.full_path }

      before_all do
        project.add_developer(current_user)
      end

      context 'with an enterprise user with allow_personal_snippets: false' do
        before do
          stub_licensed_features(allow_personal_snippets: true)
          stub_saas_features(allow_personal_snippets: true)
        end

        it 'creates a snippet' do
          expect do
            create_snippet
          end.to change { Snippet.count }.by(1)
        end
      end
    end
  end
end
