# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Jira issues list', :js, feature_category: :team_planning do
  include_context 'project integration activation'

  let_it_be(:per_page) { 20 }
  let_it_be(:public_url) { 'http://jira.foo.bar' }
  let_it_be(:api_url) { "#{public_url}/api" }
  let_it_be(:jira_project_key) { 'JIRA-GL1' }
  let_it_be(:jira_project_keys) { ['JIRA-GL1'] }
  let_it_be(:jira_user) { 'JiraGitlabUser' }
  let_it_be(:timestamp) { Time.current }

  before do
    stub_licensed_features(jira_issues_integration: true)
  end

  shared_examples 'common jira functionality' do
    it 'shows all three tabs' do
      with_issues 1 do
        within('div.issuable-list-container') do
          expect(page).to have_selector('li.nav-item', count: 3, wait: 0)
        end
      end
    end

    it 'shows the filtered search bar' do
      with_issues 10 do
        expect(page).to have_selector('div[data-testid="filtered-search-input"]')
      end
    end

    context 'when title or description contains HTML characters' do
      let(:html) { '<script>foobar</script>' }
      let(:escaped_html) { ERB::Util.html_escape(html) }
      let(:issue) { build_issue(1).deep_merge(fields: { summary: html }) }

      it 'escapes the HTML on issues#index' do
        stub_issues([issue])
        visit project_integrations_jira_issues_path(project)

        expect(page).to have_text(html)
        expect(page).not_to have_css('script', text: 'foobar')
        expect(page.source).to include(escaped_html)
      end

      it 'escapes the HTML on issues#show' do
        issue.deep_merge!(
          fields: { comment: { comments: [] } },
          renderedFields: { description: html },
          duedate: Time.zone.now.to_s
        )

        stub_request(:get, /\A#{public_url}/)
          .to_return(headers: { 'Content-Type' => 'application/json' }, body: issue.to_json)

        visit project_integrations_jira_issue_path(project, "#{jira_project_key}-1")

        expect(page).to have_text(html)
        expect(page).not_to have_css('script', text: 'foobar')
        expect(page.source).to include(escaped_html)
      end
    end
  end

  context 'with Jira Cloud integration' do
    let_it_be(:jira) do
      create(
        :jira_integration,
        :jira_cloud,
        project: project,
        project_key: jira_project_key,
        project_keys: jira_project_keys,
        issues_enabled: true,
        api_url: api_url,
        url: public_url
      )
    end

    it_behaves_like 'common jira functionality'

    it 'has a button to create a new issue in Jira' do
      with_issues 1 do
        within('div.issuable-list-container') do
          expect(page).to have_link('Create new issue in Jira', href: /#{Regexp.escape(public_url)}/)
        end
      end
    end

    it 'paginates the list results using keyset pagination' do
      with_issues 25 do |issues|
        expect(page).to have_css '.gl-keyset-pagination'

        # Verify first page shows first batch of issues with all details
        within('ul.issuable-list') do
          issues.first(per_page).each do |issue|
            verify_issue_details(issue)
          end
        end

        visit_next_page_cloud

        # Verify we're still on the issues page and pagination is working
        expect(page).to have_css '.gl-keyset-pagination'
        within('ul.issuable-list') do
          # Verify the same level of detail on the next page
          issues.first(per_page).each do |issue|
            verify_issue_details(issue)
          end
        end
      end
    end

    private

    def visit_next_page_cloud
      pagination = find '.gl-keyset-pagination'
      pagination.click_button 'Next'
    end

    def stub_issues(issues)
      # First page request (no next_page_token param)
      stub_request(:get, /\A#{public_url}/)
        .with(query: hash_not_including('nextPageToken'))
        .to_return(
          headers: { 'Content-Type' => 'application/json' },
          body: {
            issues: issues,
            isLast: false,
            nextPageToken: '**************'
          }.to_json
        )

      # Subsequent page requests (with nextPageToken param)
      stub_request(:get, /\A#{public_url}/)
        .with(query: hash_including('nextPageToken'))
        .to_return(
          headers: { 'Content-Type' => 'application/json' },
          body: {
            issues: issues,
            isLast: true,
            nextPageToken: nil
          }.to_json
        )
    end
  end

  context 'with Jira Server integration' do
    let_it_be(:jira) do
      create(
        :jira_integration,
        :jira_server,
        project: project,
        project_key: jira_project_key,
        project_keys: jira_project_keys,
        issues_enabled: true,
        api_url: api_url,
        url: public_url
      )
    end

    it_behaves_like 'common jira functionality'

    it 'has a button to create a new issue in Jira' do
      with_issues 1 do
        within('div.issuable-list-container') do
          link = page.find_link(href: /#{public_url}/, class: 'btn')
          expect(link.text).to match(/Create new issue in Jira/)
        end
      end
    end

    it 'paginates the list results using offset pagination' do
      number_of_issues = 35.0
      number_of_pages = (number_of_issues / per_page).ceil

      with_issues number_of_issues do |issues|
        expect(all_pages.size).to be(number_of_pages)

        all_pages.size.times do |page_num|
          navigate_to_page(page_num)
          offset = per_page * page_num

          aggregate_failures do
            within('ul.issuable-list') do
              issues[offset...per_page].each_with_index do |_issue, idx|
                verify_issue_details(issues[idx + offset])
              end
            end
          end
        end
      end
    end

    private

    def all_pages
      # the first and last navigation items
      # are Previous, and Next - ignore these.
      all('[data-testid="gl-pagination-li"]')[1..-2]
    end

    def navigate_to_page(page)
      all_pages[page].click
    end

    def stub_issues(issues)
      body = {
        startAt: 0,
        total: issues.size,
        maxResults: issues.size,
        issues: issues
      }

      stub_request(:get, /\A#{public_url}/)
        .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
    end
  end

  private

  def build_issues(count = 10)
    (0...count).to_a.map do |idx|
      build_issue(idx)
    end
  end

  def build_issue(idx)
    {
      id: idx,
      key: "#{jira_project_key}-#{idx}",
      fields: {
        summary: "Jira issue #{idx}",
        description: "Jira description #{idx}",
        created: (timestamp + idx).to_s,
        updated: (timestamp + idx).to_s,
        resolutiondate: nil,
        reporter: {
          name: jira_user,
          key: jira_user,
          emailAddress: "#{jira_user}@gitlab.com",
          displayName: jira_user,
          active: true,
          avatarUrls: { '48x48' => 'foo.jpg' }
        },
        labels: ["QA"],
        status: {
          description: "Status #{idx}",
          name: 'In Progress',
          statusCategory: { colorName: 'yellow', name: 'In Progress' }
        }
      }
    }
  end

  def with_issues(count)
    issues = build_issues count
    stub_issues issues
    visit project_integrations_jira_issues_path(project)
    yield issues
  end

  def verify_issue_details(issue)
    issuable_reference = issue[:key]
    issuable_row = find("li#issuable_#{issuable_reference}", wait: 0)

    expect(issuable_row.text).to include(jira_user)
    expect(issuable_row.text).to include(issue[:key])
    expect(issuable_row.text).to include(issue.dig(:fields, :summary))
    expect(issuable_row.text).to include(issue.dig(:fields, :status, :name))
    expect(issuable_row.text).to include(issue.dig(:fields, :labels, 0))
  end
end
