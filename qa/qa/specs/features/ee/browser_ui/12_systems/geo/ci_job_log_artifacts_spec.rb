# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :requires_admin, :geo, feature_category: :geo_replication do
    describe 'CI job' do
      include QA::EE::Support::Helpers::GeoGraphQl # rubocop:disable Cop/InjectEnterpriseEditionModule -- QA helpers

      let(:file_name) { 'geo_artifact.txt' }
      let(:directory_name) { 'geo_artifacts' }
      let(:pipeline_job_name) { 'test-artifacts' }
      let(:executor) { "qa-runner-#{SecureRandom.hex(6)}" }

      let(:project) { create(:project, name: 'geo-project-with-artifacts') }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }

      before do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              test-artifacts:
                tags:
                  - '#{executor}'
                artifacts:
                  paths:
                    - '#{directory_name}'
                  expire_in: 1000 seconds
                script:
                  - |
                    mkdir #{directory_name}
                    echo "CONTENTS" > #{directory_name}/#{file_name}
            YAML
          }
        ])
      end

      after do
        runner.remove_via_api!
      end

      it 'job artifacts successfully replicate to secondary Geo site' do
        admin_api_client = Runtime::API::Client.as_admin

        Runtime::Logger.info("Runner registration address: #{Runtime::Scenario.gitlab_address}")
        Runtime::Logger.info("Geo primary address: #{Runtime::Scenario.geo_primary_address}")

        Support::Waiter.wait_until(
          max_duration: QA::EE::Runtime::Geo.max_file_replication_time * 3,
          sleep_interval: 10,
          message: 'Wait for pipeline to finish'
        ) do
          project.pipelines.present? &&
            %w[success failed canceled].include?(project.latest_pipeline[:status])
        end

        job = create(:job, project: project, id: project.job_by_name(pipeline_job_name)[:id])
        expect(job.status).to eq('success'),
          "Expected CI job '#{pipeline_job_name}' to succeed. Trace:\n#{job.trace}"

        artifacts = job.artifacts
        expect(artifacts).not_to be_empty,
          "Expected CI job '#{pipeline_job_name}' to produce artifacts. Trace:\n#{job.trace}"

        Runtime::Logger.info("Job #{job.id} succeeded with artifacts: #{artifacts.pluck(:filename).join(', ')}")

        # The jobs REST API does not expose job artifact IDs, so fetch the
        # archive artifact's ID via the primary's GraphQL API
        archive_artifact_id = fetch_archive_artifact_id(admin_api_client, job.id)
        raise "No archive artifact found for CI job '#{pipeline_job_name}'" unless archive_artifact_id

        wait_for_job_artifact_replication(admin_api_client, job_artifact_id: archive_artifact_id)

        Runtime::Logger.info("Job artifact successfully replicated to secondary")
      end

      def fetch_archive_artifact_id(api_client, job_id)
        query = <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              job(id: "gid://gitlab/Ci::Build/#{job_id}") {
                artifacts {
                  nodes {
                    id
                    fileType
                  }
                }
              }
            }
          }
        GRAPHQL

        url = Runtime::API::Request.new(api_client, '/graphql').url
        response = Support::API.post(url, { query: query }.to_json, headers: { 'Content-Type' => 'application/json' })

        unless Support::API.success?(response.code)
          raise "Failed to fetch job artifacts via GraphQL: #{response.code} - #{response.body}"
        end

        body = Support::API.parse_body(response)
        nodes = body.dig(:data, :project, :job, :artifacts, :nodes) || []
        archive = nodes.find { |node| node[:fileType] == 'ARCHIVE' }
        archive && archive[:id][/\d+\z/].to_i
      end
    end
  end
end
