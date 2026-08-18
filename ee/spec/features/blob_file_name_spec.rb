# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User browses repository files', :js, :saas, feature_category: :source_code_management do
  let_it_be(:group) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project_member) { create(:project_member, :owner, project: project, user: user) }

  before_all do
    group.add_maintainer(user)

    project.repository.commit_files(
      user,
      branch_name: 'main',
      message: 'Add a file',
      actions: [
        {
          action: :create,
          file_path: '/file-a',
          content: 'foobar'
        },
        {
          action: :create,
          file_path: '/file-b',
          content: 'foobar'
        },
        {
          action: :create,
          file_path: '/file-c',
          content: 'bazfoo'
        }
      ]
    )
  end

  include_context 'with duo features enabled and agentic chat available for group on SaaS'

  before do
    sign_in(user)
    visit namespace_project_tree_path(project.namespace, project.path, 'main')
  end

  it_behaves_like 'user can use explain code' do
    subject { project_blob_path(project, File.join('main', 'file-a')) }
  end

  it_behaves_like 'user can use agentic chat' do
    subject { project_blob_path(project, File.join('main', 'file-a')) }
  end

  it_behaves_like 'user can navigate AI panel using navigation rail' do
    subject { project_blob_path(project, File.join('main', 'file-a')) }
  end

  describe 'blob filename' do
    shared_examples 'shows the correct filename' do
      it 'shows the correct filename' do
        within_testid('file-tree-table') { click_link(first_file) }
        expect(page).to have_content(first_file_tittle)
        expect(page).to have_content(first_file_content)
        expect(page).not_to have_content(second_file_tittle)

        page.go_back

        within_testid('file-tree-table') { click_link(second_file) }
        expect(page).to have_content(second_file_tittle)
        expect(page).to have_content(second_file_content)
        expect(page).not_to have_content(first_file_tittle)

        page.go_back

        within_testid('file-tree-table') { click_link(first_file) }
        expect(page).to have_content(first_file_tittle)
        expect(page).to have_content(first_file_content)
        expect(page).not_to have_content(second_file_tittle)
      end
    end

    context 'when identical files are cached' do
      let(:first_file) { 'file-a' }
      let(:first_file_tittle) { 'file-a' }
      let(:first_file_content) { 'foobar' }
      let(:second_file) { 'file-b' }
      let(:second_file_tittle) { 'file-b' }
      let(:second_file_content) { 'foobar' }

      it_behaves_like 'shows the correct filename'
    end

    context 'when different files are cached' do
      let(:first_file) { 'file-a' }
      let(:first_file_tittle) { 'file-a' }
      let(:first_file_content) { 'foobar' }
      let(:second_file) { 'file-c' }
      let(:second_file_tittle) { 'file-c' }
      let(:second_file_content) { 'bazfoo' }

      it_behaves_like 'shows the correct filename'
    end
  end
end
