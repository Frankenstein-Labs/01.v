# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User sees status checks widget', :js, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }

  let_it_be(:check_pending) do
    create(
      :external_status_check,
      project: project,
      external_url: "http://test1.host"
    )
  end

  let_it_be(:check_failed) do
    create(
      :external_status_check,
      project: project,
      external_url: "http://test2.host"
    )
  end

  let_it_be(:check_passed) do
    create(
      :external_status_check,
      project: project,
      external_url: "http://test3.host"
    )
  end

  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:status_check_response_passed) { create(:status_check_response, external_status_check: check_passed, merge_request: merge_request, sha: merge_request.source_branch_sha, status: 'passed') }
  let_it_be(:status_check_response_failed) { create(:status_check_response, external_status_check: check_failed, merge_request: merge_request, sha: merge_request.source_branch_sha, status: 'failed') }

  shared_examples 'no status checks widget' do
    it 'does not show the widget' do
      expect(page).not_to have_selector('[data-testid="widget-extension"]')
    end
  end

  before do
    stub_licensed_features(external_status_checks: true)
  end

  context 'user is authorized' do
    before do
      project.add_maintainer(user)
      sign_in(user)

      visit project_merge_request_path(project, merge_request)
    end

    it 'shows the widget' do
      expect(page).to have_content('Status checks 1 failed, 1 pending')
    end

    where(:check, :icon_class) do
      lazy { check_pending } | '.gl-text-gray-400'
      lazy { check_passed } | '.gl-text-success'
      lazy { check_failed } | '.gl-text-danger'
    end

    with_them do
      it 'is rendered correctly', :aggregate_failures, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/439546' do
        within_testid('info-status-checks') do
          find_by_testid('toggle-button').click
        end

        within_testid('info-status-checks') do
          expect(page).to have_css(icon_class)
          expect(page).to have_content("#{check.name}: #{check.external_url}")
          expect(page).to have_content("Status Check ID: #{check.id}")
        end
      end
    end
  end

  context 'user is not logged in' do
    before do
      visit project_merge_request_path(project, merge_request)
    end

    it_behaves_like 'no status checks widget'
  end
end
