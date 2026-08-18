# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', :external_api_calls, feature_category: :vulnerability_management do
    describe 'Security Reports' do
      let(:number_of_dependencies_dependency_scanning) { 9 }
      let(:dependency_scan_example_vuln) { 'Prototype pollution attack in mixin-deep' }
      let(:container_scan_example_vuln) { 'CVE-2017-18269 in glibc' }
      let(:sast_scan_example_vuln) { 'Cipher with no integrity' }
      let(:dast_scan_example_vuln) { 'Flask debug mode identified on target:7777' }
      let(:sast_scan_fp_example_vuln) { "Possible unprotected redirect" }
      let(:secret_detection_vuln) { "Typeform API token" }

      let!(:gitlab_ci_yaml_path) { File.join(EE::Runtime::Path.fixture('secure_premade_reports'), '.gitlab-ci.yml') }
      let!(:cyclonedx_json) do
        File.join(EE::Runtime::Path.fixture('secure_premade_reports'), 'gl-sbom.json')
      end

      let!(:ci_yaml_content) do
        original_yaml = File.read(gitlab_ci_yaml_path)
        original_yaml << "\n"
        original_yaml << <<~YAML
          secret_detection:
            tags: [secure_report]
            script:
              - echo "Skipped"
            artifacts:
              reports:
                secret_detection: gl-secret-detection-report.json
        YAML
      end

      let(:group) { create(:group, path: "govern-security-reports-#{Faker::Alphanumeric.alphanumeric(number: 6)}") }
      let!(:dependency_scan_yaml) do
        <<~YAML
          dependency_scanning:
            tags: [secure_report]
            script:
              - echo "Skipped"
            artifacts:
              reports:
                cyclonedx: gl-sbom.json
        YAML
      end

      let!(:project) do
        create(:project, name: 'project-with-secure', description: 'Project with Secure', group: group)
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}", tags: ['secure_report'])
      end

      before do
        Flow::Login.sign_in_unless_signed_in
        project.visit!
      end

      after do
        runner&.remove_via_api! if runner
      end

      it 'dependency list has empty state' do
        Page::Project::Menu.perform(&:go_to_dependency_list)

        EE::Page::Project::Secure::DependencyList.perform do |dependency_list|
          expect(dependency_list).to have_empty_state_description(
            'The dependency list details information about the components used within your project.'
          )
          expect(dependency_list).to have_link(
            'More Information',
            href: %r{/help/user/application_security/dependency_list/_index}
          )
        end
      end

      it 'displays security reports in the pipeline' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success
        Flow::Pipeline.visit_latest_pipeline
        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.click_on_security

          pipeline.filter_by(token_name: "Report type", token_value: "Dependency Scanning")
          expect(pipeline).to have_vulnerability dependency_scan_example_vuln

          pipeline.filter_by(token_name: "Report type", token_value: "Container Scanning")
          expect(pipeline).to have_vulnerability container_scan_example_vuln

          pipeline.filter_by(token_name: "Report type", token_value: "SAST")
          expect(pipeline).to have_vulnerability sast_scan_example_vuln
          expect(pipeline).to have_vulnerability sast_scan_fp_example_vuln

          pipeline.filter_by(token_name: "Report type", token_value: "DAST")
          expect(pipeline).to have_vulnerability dast_scan_example_vuln

          pipeline.filter_by(token_name: "Report type", token_value: "Secret Detection")
          expect(pipeline).to have_vulnerability secret_detection_vuln
        end
      end

      it 'displays security reports in the project security dashboard' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success
        Page::Project::Menu.perform(&:click_project)
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::VulnerabilityReport.perform(&:wait_for_vuln_report_to_ingest)

        EE::Page::Project::Secure::Show.perform do |vulnerability_report|
          vulnerability_report.filter_by(token_name: "Scanner", token_value: "gemnasium")
          expect(vulnerability_report).to have_vulnerability dependency_scan_example_vuln

          vulnerability_report.filter_by(token_name: "Scanner", token_value: "Trivy")
          expect(vulnerability_report).to have_vulnerability container_scan_example_vuln

          vulnerability_report.filter_by(token_name: "Scanner", token_value: "Brakeman")
          expect(vulnerability_report).to have_vulnerability sast_scan_example_vuln
          expect(vulnerability_report).to have_vulnerability sast_scan_fp_example_vuln
          expect(vulnerability_report).to have_false_positive_vulnerability

          vulnerability_report.filter_by(token_name: "Scanner", token_value: "GitLab API Security")
          expect(vulnerability_report).to have_vulnerability dast_scan_example_vuln

          vulnerability_report.filter_by(token_name: "Scanner", token_value: "Gitleaks")
          expect(vulnerability_report).to have_vulnerability secret_detection_vuln
        end
      end

      it 'displays security reports in the group security dashboard' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success

        project.group.visit!

        Page::Group::Menu.perform(&:go_to_security_dashboard)

        # Check if new dashboard is being used by looking for the test-id element
        is_new_dashboard = has_element?('data-testid': 'group-security-dashboard-new')

        if is_new_dashboard
          # Handle the new dashboard implementation
          EE::Page::Group::Secure::Show.perform do |_|
            Support::Retrier.retry_on_exception(
              max_attempts: 2,
              reload_page: page,
              message: "Retry project visibility in new security dashboard"
            ) do
              expect(page).to have_content('Security dashboard')
            end
          end
        else
          # Original implementation for when the feature flag is disabled
          EE::Page::Group::Secure::Show.perform do |dashboard|
            Support::Retrier.retry_on_exception(
              max_attempts: 2,
              reload_page: page,
              message: "Retry project security status in security dashboard"
            ) do
              expect(dashboard).to have_security_status_project_for_severity('F', project)
            end
          end
        end

        Page::Group::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Group::Secure::Show.perform do |dashboard|
          dashboard.filter_project(project_name: project.name)

          dashboard.filter_by(token_name: 'Report type', token_value: "Dependency Scanning")
          expect(dashboard).to have_vulnerability dependency_scan_example_vuln

          dashboard.filter_by(token_name: 'Report type', token_value: "Container Scanning")
          expect(dashboard).to have_vulnerability container_scan_example_vuln

          dashboard.filter_by(token_name: 'Report type', token_value: "SAST")
          expect(dashboard).to have_vulnerability sast_scan_example_vuln

          dashboard.filter_by(token_name: 'Report type', token_value: "DAST")
          expect(dashboard).to have_vulnerability dast_scan_example_vuln

          dashboard.filter_by(token_name: 'Report type', token_value: "Secret Detection")
          expect(dashboard).to have_vulnerability secret_detection_vuln
        end
      end

      context 'for dependency scanning' do
        it 'displays the Dependency List' do
          commit_scan_files(fixture_json: cyclonedx_json, ci_yaml_content: dependency_scan_yaml)
          project.visit!
          wait_for_pipeline_success
          Page::Project::Menu.perform(&:go_to_dependency_list)

          EE::Page::Project::Secure::DependencyList.perform do |dependency_list|
            expect(dependency_list).to have_dependency_count_of number_of_dependencies_dependency_scanning
          end
        end
      end

      def push_security_reports
        build(:commit,
          project: project,
          commit_message: 'Create Secure compatible application to serve premade reports') do |commit|
          commit.add_directory(Pathname.new(EE::Runtime::Path.fixture('dismissed_security_findings_mr_widget')))
          commit.add_directory(Pathname.new(EE::Runtime::Path.fixture('secure_premade_reports')))
          commit.update_files([ci_file])
        end.fabricate_via_api!
      end

      def commit_scan_files(fixture_json:, ci_yaml_content:)
        create(:commit, project: project, commit_message: 'Commit dependency scanning files', actions: [
          { action: 'create', file_path: File.basename(fixture_json), content: File.read(fixture_json) },
          { action: 'create', file_path: '.gitlab-ci.yml', content: ci_yaml_content }
        ])
      end

      def wait_for_pipeline_success
        Support::Waiter.wait_until(sleep_interval: 10, message: "Check for pipeline success", max_duration: 90) do
          latest_pipeline.status == 'success'
        end
      end

      def latest_pipeline
        Support::Waiter.wait_until(sleep_interval: 2, message: "Waiting for pipelines api endpoint to populate") do
          !project.pipelines.empty?
        end
        create(:pipeline, project: project, id: project.latest_pipeline[:id]) # Fetch existing pipeline object
      end

      def ci_file
        {
          file_path: '.gitlab-ci.yml',
          content: ci_yaml_content
        }
      end
    end
  end
end
