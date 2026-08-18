# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User merges with push rules', :js, feature_category: :code_review_workflow do
  let(:user) { create(:user) }
  let(:project) do
    create(:project, :public, :repository, push_rule: push_rule, only_allow_merge_if_pipeline_succeeds:
                         false)
  end

  let(:merge_request) do
    create(:merge_request_with_diffs, source_project: project, author: user, title: 'Bug NS-04',
      merge_status: 'can_be_merged')
  end

  before do
    project.add_maintainer(user)
  end

  context 'when merge commit template is set and no commit message is given' do
    let(:push_rule) { create(:push_rule, commit_message_regex: "Bug.+") }
    let(:merge_request) do
      create(:merge_request_with_diffs, source_project: project, author: user, title: 'Draft: Bug NS-04',
        merge_status: 'can_be_merged')
    end

    before do
      project.update!(merge_commit_template_or_default: "%{title}: %{approved_by}")

      sign_in user
      visit_merge_request(merge_request)
    end

    it 'merges successfuly', :sidekiq_inline do
      click_button 'Set to auto-merge'

      create(:approval, merge_request: merge_request, user: user)
      create(:ci_pipeline, :success,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha,
        project: merge_request.source_project)
      merge_request.update_head_pipeline

      click_button('Mark as ready')

      expect(page).to have_content("#{user.name} merged just now")
      expect(merge_request.reload.merge_commit.message).to match(/Bug NS-04: Approved-by: #{user.name}/)
    end
  end

  context 'commit message is invalid' do
    let(:push_rule) { create(:push_rule, :commit_message) }

    before do
      sign_in user
      visit_merge_request(merge_request)
    end

    it 'displays error message after merge request is clicked' do
      click_merge_button

      expect(page).to have_content("Commit message does not follow the pattern '#{push_rule.commit_message_regex}'")
    end
  end

  context 'author email is invalid' do
    let(:push_rule) { create(:push_rule, :author_email) }

    before do
      sign_in user
      visit_merge_request(merge_request)
    end

    it 'displays error message after merge request is clicked' do
      click_merge_button

      expect(page).to have_content("Author's commit email '#{user.email}' does not follow the pattern '#{push_rule.author_email_regex}'")
    end
  end

  def visit_merge_request(merge_request)
    visit project_merge_request_path(merge_request.project, merge_request)
  end

  def click_merge_button
    page.within('.mr-state-widget') do
      click_button 'Merge'
    end
  end
end
