# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Merge request > User sees security widget",
  :js, :sidekiq_inline, :use_clean_rails_memory_store_caching,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:merge_request) { create(:merge_request, :simple, :with_sast_reports, source_project: project) }
  let(:user) { project.creator }

  let(:feature_branch_start_sha) { "ae73cb07c9eeaf35924a10f713b364d32b2dd34f" }
  let(:mr_widget_app_selector) { "[data-testid='mr-widget-app']" }
  let(:merge_request_path) { project_merge_request_path(project, merge_request) }

  before do
    stub_licensed_features(
      security_dashboard: true,
      sast: true
    )

    project.add_developer(user)
    sign_in(user)
  end

  context "when there are changes in the vulnerabilities detected" do
    before do
      # Create security scan to enable SAST scanning
      create(
        :security_scan,
        :latest_successful,
        :with_findings,
        project: project,
        pipeline: merge_request.head_pipeline,
        scan_type: 'sast',
        status: :succeeded
      )
    end

    it "shows the security widget" do
      visit(merge_request_path)

      page.within(mr_widget_app_selector) do
        expect(page).to have_content(
          "Security scanning detected 5 new potential vulnerabilities"
        )
      end
    end
  end

  context "when vulnerabilities in an MR have already been detected on main" do
    let!(:ci_pipeline) do
      create(
        :ci_pipeline,
        :success,
        :with_sast_report,
        project: project,
        sha: feature_branch_start_sha
      )
    end

    before do
      # Create security scan to enable SAST scanning for the main pipeline
      create(
        :security_scan,
        status: :succeeded,
        pipeline: ci_pipeline,
        scan_type: 'sast'
      )

      # Create security scan for the MR pipeline as well
      create(
        :security_scan,
        status: :succeeded,
        pipeline: merge_request.head_pipeline,
        scan_type: 'sast'
      )
    end

    it "does not show them as new vulnerabilities" do
      visit(merge_request_path)

      page.within(mr_widget_app_selector) do
        expect(page).to have_content(
          "Security scanning detected no new potential vulnerabilities"
        )
      end
    end
  end

  context "when master detects vulnerabilities in a child pipeline" do
    context 'and merge request detects the same vulnerabilities not in a child pipeline' do
      let(:parent_pipeline) do
        create(
          :ci_pipeline,
          :success,
          project: project,
          sha: feature_branch_start_sha
        )
      end

      let!(:child_pipeline) do
        create(
          :ci_pipeline,
          :success,
          :with_sast_report,
          project: project,
          child_of: parent_pipeline,
          sha: feature_branch_start_sha
        )
      end

      before do
        # Create security scan for the child pipeline
        create(
          :security_scan,
          status: :succeeded,
          pipeline: child_pipeline,
          scan_type: 'sast'
        )

        # Create security scan for the MR pipeline
        create(
          :security_scan,
          status: :succeeded,
          pipeline: merge_request.head_pipeline,
          scan_type: 'sast'
        )
      end

      it "does not show them as new vulnerabilities" do
        visit(merge_request_path)

        page.within(mr_widget_app_selector) do
          expect(page).to have_content(
            "Security scanning detected no new potential vulnerabilities"
          )
        end
      end
    end
  end

  describe 'dismissal descriptions' do
    let(:dismissal_descriptions_json) do
      Gitlab::Json.parse(fixture_file('vulnerabilities/dismissal_descriptions.json', dir: 'ee')).to_json
    end

    before do
      # Create security scan to enable SAST scanning
      create(
        :security_scan,
        status: :succeeded,
        pipeline: merge_request.head_pipeline,
        scan_type: 'sast'
      )
    end

    it 'loads dismissal descriptions' do
      visit(merge_request_path)
      expect(page.evaluate_script('window.gl.mrWidgetData.dismissal_descriptions')).to match(
        dismissal_descriptions_json
      )
    end
  end

  it 'sets commit_path_template' do
    # Create security scan to enable SAST scanning
    create(
      :security_scan,
      status: :succeeded,
      pipeline: merge_request.head_pipeline,
      scan_type: 'sast'
    )

    visit(merge_request_path)
    expect(page.evaluate_script('window.gl.mrWidgetData.commit_path_template')).to eq(
      "/#{project.path_with_namespace}/-/commit/$COMMIT_SHA"
    )
  end

  context 'when there is a jira integration' do
    let(:jira_integration) do
      create(:jira_integration,
        project: project,
        issues_enabled: true,
        project_key: 'FE',
        project_keys: %w[FE BE],
        vulnerabilities_enabled: true,
        vulnerabilities_issuetype: '10001',
        customize_jira_issue_enabled: false)
    end

    it 'sets customize_jira_issue_enabled' do
      allow(project).to receive(:jira_integration).and_return(jira_integration)

      visit(merge_request_path)
      expect(page.evaluate_script('window.gl.mrWidgetData.customize_jira_issue_enabled')).to match('false')
    end
  end
end
