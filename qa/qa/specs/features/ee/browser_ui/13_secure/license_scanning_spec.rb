# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', feature_category: :software_composition_analysis,
    only: { pipeline: %i[staging staging-canary] } do
    describe 'License Scanning' do
      let!(:test_project) do
        create(:project, :with_readme, name: 'license-scanning-project', description: 'License Scanning Project')
      end

      let!(:licenses) do
        ['Apache License 2.0', 'BSD 2-Clause "Simplified" License',
          'BSD 3-Clause "New" or "Revised" License', 'Creative Commons Attribution 3.0 Unported',
          'Creative Commons Zero v1.0 Universal', 'ISC License', 'MIT License', 'The Unlicense',
          'unknown']
      end

      let!(:runner) do
        create(:project_runner,
          project: test_project,
          name: "runner-for-#{test_project.name}",
          tags: ['secure_license_scanning'],
          executor: :docker)
      end

      let!(:source) do
        create(:commit,
          project: test_project,
          branch: 'license-management-mr',
          start_branch: test_project.default_branch,
          actions: [
            {
              action: 'create',
              file_path: '.gitlab-ci.yml',
              content: File.read(
                File.join(
                  EE::Runtime::Path.fixtures_path, 'secure_license_scanning_files',
                  '.gitlab-ci.yml'
                )
              )
            },
            {
              action: 'create',
              file_path: 'package.json',
              content: File.read(
                File.join(
                  EE::Runtime::Path.fixtures_path,
                  'secure_license_scanning_files',
                  'package.json'
                )
              )
            },
            {
              action: 'create',
              file_path: 'package-lock.json',
              content: File.read(
                File.join(
                  EE::Runtime::Path.fixtures_path,
                  'secure_license_scanning_files',
                  'package-lock'
                )
              )
            }
          ])
      end

      after do
        runner&.remove_via_api!
      end

      context 'when populated by a Dependency Scan' do
        it 'populates licenses in the pipeline and merge request' do
          merge_request = create(:merge_request,
            source: source,
            project: test_project,
            source_branch: 'license-management-mr',
            target_branch: test_project.default_branch)

          Flow::Login.sign_in_unless_signed_in

          merge_request.visit!

          Page::MergeRequest::Show.perform do |mr|
            mr.wait_for_license_compliance_report
            mr.merge_immediately!
          end

          Flow::Pipeline.wait_for_pipeline_creation_via_api(project: test_project)
          Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: test_project, status: 'success')

          # Visit pipeline in UI to verify licenses appear in the license report
          test_project.visit_latest_pipeline

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.click_on_licenses
            licenses.each do |license|
              expect(pipeline).to have_license(license)
            end
          end
        end
      end
    end
  end
end
