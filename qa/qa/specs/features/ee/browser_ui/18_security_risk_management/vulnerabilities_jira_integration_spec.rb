# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', :jira, :orchestrated, :requires_admin,
    feature_category: :vulnerability_management do
    describe 'vulnerability report with jira integration' do
      let(:jira_project_key) { 'JITP' }
      let!(:project) do
        create(:project,
          :with_readme,
          name: 'vulnerabilities-jira-integration',
          description: 'Project with vulnerabilities for JIRA integration test')
      end

      let(:vulnerabilities) do
        { "Cricket vulnerability": "Describes a game with a bat and a ball",
          "Football vulnerability": "Describes a ball and two goal posts",
          "Basketball vulnerability": "Describes a ball and two hoops",
          "Tennis vulnerability": "Describes a ball two rackets and a net" }
      end

      let!(:vulnerability_report) do
        vulnerabilities.each do |name, description|
          QA::EE::Resource::VulnerabilityItem.fabricate_via_api! do |vulnerability|
            vulnerability.id = project.id
            vulnerability.severity = vuln_severity
            vulnerability.name = name
            vulnerability.description = description
          end
        end
      end

      let(:vuln_name) { "Cricket vulnerability" }
      let(:vuln_severity) { :CRITICAL }
      let(:jira_issue_summary) { "Investigate vulnerability: #{vuln_name}" }
      let(:jira_host) { Vendor::Jira::JiraAPI.perform(&:base_url) }

      before do
        Flow::Login.sign_in
        project.visit!
        set_up_jira_integration
      end

      it 'can successfully create a JIRA issue from vulnerability details page' do
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::VulnerabilityReport.perform do |vulnerability_report|
          expect(vulnerability_report).to have_vulnerability(description: vuln_name)

          vulnerability_report.click_vulnerability(description: vuln_name)
        end

        EE::Page::Project::Secure::VulnerabilityDetails.perform(&:click_create_jira_issue_button)

        QA::Support::WaitForRequests.wait_for_requests

        jira_link = "#{jira_host}/browse/#{jira_project_key}"
        EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability|
          expect(vulnerability.jira_issue_link_present?(jira_issue_summary, jira_link)).to be true
        end
      end

      def set_up_jira_integration
        Runtime::ApplicationSettings.set_application_settings(allow_local_requests_from_web_hooks_and_services: true)

        page.visit Runtime::Scenario.gitlab_address
        Flow::Login.sign_in_unless_signed_in

        project.visit!

        Page::Project::Menu.perform(&:go_to_integrations_settings)
        QA::Page::Project::Settings::Integrations.perform(&:click_jira_link)

        QA::Page::Project::Settings::Services::Jira.perform do |jira|
          jira.setup_service_with(url: jira_host)
          jira.enable_jira_vulnerabilities
          jira.set_jira_project_key(jira_project_key)
          jira.select_vulnerability_bug_type("Bug")
          jira.click_save_changes_and_wait
        end

        expect(page).not_to have_text("Url is blocked")
        expect(page).to have_text("Jira issues settings saved and active.")
      end
    end
  end
end
