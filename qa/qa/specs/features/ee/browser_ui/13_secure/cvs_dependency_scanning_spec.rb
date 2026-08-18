# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :orchestrated, :skip_live_env, :secure_cvs,
    feature_category: :software_composition_analysis do
    describe 'Continuous Vulnerability Scanning' do
      context 'when new vulnerabilities are ingested' do
        let!(:test_project) do
          create(:project, :with_readme, name: 'cvs-project', description: 'Continuous Vulnerability Scanning Project')
        end

        let!(:runner) do
          create(:project_runner,
            project: test_project,
            name: "runner-for-#{test_project.name}",
            tags: ['secure_cvs_scanning'],
            executor: :docker)
        end

        before do
          create_source_commit

          Flow::Login.while_signed_in_as_admin do
            Page::Main::Menu.perform(&:go_to_admin_area)
            Page::Admin::Menu.perform(&:go_to_security_and_compliance_settings)
            EE::Page::Admin::Settings::Securityandcompliance.perform(&:select_gem_checkbox)
          end

          Flow::Login.sign_in
          test_project.visit!
          Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: test_project, status: 'success', wait: 600)
          Page::Project::Menu.perform(&:go_to_vulnerability_report)
        end

        it('updates the vulnerability list with new vulnerabilities within the past 14 days',
          quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/20448', type: :flaky }
        ) do
          EE::Page::Project::Secure::VulnerabilityReport.perform do |vulnerability_report|
            expect(vulnerability_report).to have_vulnerability(description: 'Inefficient Regular Expression Complexity')

            Support::Retrier.retry_until(max_duration: 120, sleep_interval: 15, reload_page: vulnerability_report) do
              vulnerability_report.has_vulnerability?(description: 'Arbitrary test vulnerability')
            end

            vulnerability_report.click_vulnerability(description: 'Arbitrary test vulnerability')
          end

          EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
            expect(vulnerability_details).to have_vulnerable_package('RedCloth:2.0.0')
          end
        end

        def create_source_commit
          create(:commit,
            project: test_project,
            branch: test_project.default_branch,
            actions: [
              {
                action: 'create',
                file_path: '.gitlab-ci.yml',
                content: File.read(
                  File.join(
                    EE::Runtime::Path.fixtures_path, 'secure_cvs_files',
                    '.gitlab-ci.yml'
                  )
                )
              },
              {
                action: 'create',
                file_path: 'Gemfile',
                content: File.read(
                  File.join(
                    EE::Runtime::Path.fixtures_path,
                    'secure_cvs_files',
                    'Gemf'
                  )
                )
              },
              {
                action: 'create',
                file_path: 'Gemfile.lock',
                content: File.read(
                  File.join(
                    EE::Runtime::Path.fixtures_path,
                    'secure_cvs_files',
                    'Gemf.lock'
                  )
                )
              }
            ]
          )
        end
      end
    end
  end
end
