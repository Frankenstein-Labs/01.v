# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :secure_container_reg_cvs,
    feature_category: :software_composition_analysis,
    only: { pipeline: %i[staging staging-canary] },
    feature_flag: { name: 'cvs_for_container_scanning', scope: :project },
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/12',
      type: :investigating
    } do
    describe 'Continuous Vulnerability Scanning' do
      let(:image_tag) { 'alpine:3.10.0' }
      let(:registry_password_token) { ENV.fetch('GITLAB_QA_ACCESS_TOKEN') { raise 'GITLAB_QA_ACCESS_TOKEN required' } }

      let!(:project) do
        create(:project, :with_readme,
          name: 'container-registry-cvs-project',
          description: 'Container Registry CVS Project')
      end

      let(:registry_host) do
        address = Runtime::Scenario.gitlab_address
        uri = address.is_a?(URI) ? address : URI.parse(address)
        "registry.#{uri.host}"
      end

      let(:new_image_tag) { "#{registry_host}/#{project.full_path}:latest" }
      let(:docker_utils) { QA::Service::DockerRun::ContainerRegistryUtils.new(image: image_tag) }

      before do
        Runtime::Feature.enable(:cvs_for_container_scanning, project: project)
        Flow::Login.sign_in
      end

      context 'when a container is tagged with latest' do
        it 'performs a container scan' do
          configure_security_scanning
          push_container_image
          verify_scanning_job
          navigate_to_vulnerability_details
          EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
            expect(vulnerability_details).to have_scanner('GitLab SBoM Vulnerability Scanner')
          end
        end
      end

      private

      def configure_security_scanning
        project.visit!
        Page::Project::Menu.perform(&:go_to_security_configuration)
        Page::Project::Secure::ConfigurationForm.perform(&:enable_reg_scan)
      end

      def push_container_image
        docker_utils.pull
        docker_utils.login(registry_host,
          user: Runtime::Env.user_username,
          password: registry_password_token)
        docker_utils.tag_image(new_image_tag)
        docker_utils.push_image(new_image_tag)
      end

      def verify_scanning_job
        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: project)
        project.visit_job('container_scanning')
        Page::Project::Job::Show.perform do |job|
          expect(job).to be_successful(timeout: 800)
        end
      end

      def navigate_to_vulnerability_details
        Page::Project::Menu.perform(&:go_to_container_registry)
        Page::Project::Registry::Show.perform do |registry|
          expect(registry).to have_registry_repository(project.name)
          expect(registry).to have_non_zero_counts
          registry.click_link_with_text('View vulnerabilities')
        end
        EE::Page::Project::Secure::VulnerabilityReport.perform do |vulnerability_report|
          vulnerability_report.click_vulnerability(
            description: 'apk-tools in alpine 3.10.0 is vulnerable to CVE-2021-30139')
        end
      end
    end
  end
end
