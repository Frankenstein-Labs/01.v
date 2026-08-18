# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > Batch comments', :js, :sidekiq_inline, feature_category: :code_review_workflow do
  include MergeRequestDiffHelpers
  include RepoHelpers

  let(:project) { create(:project, :public, :repository, merge_requests_author_approval: true) }
  let(:current_user) { project.owner }
  let(:merge_request) do
    create(:merge_request_with_diffs, source_project: project, target_project: project, source_branch: 'merge-test')
  end

  before do
    create(:draft_note, merge_request: merge_request, author: current_user)

    sign_in(current_user)

    visit project_merge_request_path(merge_request.project, merge_request)

    wait_for_requests
  end

  context 'when submitting a review with a comment' do
    it 'publishes the review' do
      page.within '.merge-request-tabs-container' do
        click_button 'Your review'
      end

      find_by_testid('placeholder-input-field').click

      find('textarea[data-testid="comment-textarea"]').set('overview comment')

      click_button 'Submit review'

      wait_for_requests
      expect(page).not_to have_content('Pending comments 1')
    end
  end

  context 'with approval' do
    context 'when user does not have permission to approve' do
      let(:current_user) { create(:user) }

      it 'does not allow user to approve' do
        page.within '.merge-request-tabs-container' do
          click_button 'Your review'
        end

        expect(page).to have_selector('[data-testid="reviewer_states"] .custom-control-input[disabled]')
      end
    end

    context 'when user has permission to approve' do
      it 'allows user to approve' do
        page.within '.merge-request-tabs-container' do
          click_button 'Your review'
        end

        all('[data-testid="reviewer_states"] .custom-control-label')[1].click

        click_button 'Submit review'

        wait_for_requests

        expect(page).to have_content('approved this merge request')
      end

      context 'when password is required for approval' do
        let(:project) do
          # rubocop:disable Layout/LineLength
          create(:project, :public, :repository, require_password_to_approve: true, merge_requests_author_approval: true)
          # rubocop:enable Layout/LineLength
        end

        it 'does not allow user to approve without password' do
          page.within '.merge-request-tabs-container' do
            click_button 'Your review'
          end

          all('[data-testid="reviewer_states"] .custom-control-label')[1].click
          click_button 'Submit review'

          wait_for_requests

          expect(page).not_to have_content('approved this merge request')
        end

        it 'allows user to approve' do
          page.within '.merge-request-tabs-container' do
            click_button 'Your review'
          end

          all('[data-testid="reviewer_states"] .custom-control-label')[1].click
          fill_in(type: 'password', with: current_user.password)
          click_button 'Submit review'

          wait_for_requests

          expect(page).to have_content('approved this merge request')
        end
      end
    end
  end
end
