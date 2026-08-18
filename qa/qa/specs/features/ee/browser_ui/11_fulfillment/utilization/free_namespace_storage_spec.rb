# frozen_string_literal: true

module QA
  RSpec.describe 'Fulfillment', :requires_admin, feature_category: :consumables_cost_management,
    only: { subdomain: :staging },
    feature_flag: { name: 'namespace_storage_limit', scope: :group } do
    describe 'Utilization' do
      include Runtime::Fixtures

      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:hash) { SecureRandom.hex(8) }
      let(:content) { Faker::Lorem.paragraph(sentence_count: 1000) }
      let(:free_plan_group) do
        Resource::Sandbox.fabricate! do |sandbox|
          sandbox.path = "fulfillment-free-plan-group-#{hash}"
          sandbox.api_client = admin_api_client
        end
      end

      let(:project) do
        create(:project,
          name: "free-project-#{hash}",
          template_name: 'express',
          group: free_plan_group,
          api_client: admin_api_client)
      end

      before do
        Flow::Login.sign_in

        Runtime::Feature.enable(:reduce_aggregation_schedule_lease, group: free_plan_group)

        endpoint = QA::Runtime::API::Request.new(admin_api_client, '/application/settings').url
        put endpoint, { namespace_aggregation_schedule_lease_duration_in_seconds: 120 }

        create(:commit, api_client: admin_api_client, project: project, commit_message: 'Add large file', actions: [
          { action: 'create', file_path: 'test.rb', content: SecureRandom.hex(10000) } # 10.2 KiB
        ])

        create(:commit, api_client: admin_api_client, project: project, commit_message: 'Add CI file', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              container-registry:
                image: docker:24.0.1
                services:
                  - docker:24.0.1-dind
                variables:
                  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG
                  DOCKER_HOST: tcp://docker:2376
                  DOCKER_TLS_CERTDIR: "/certs"
                  DOCKER_TLS_VERIFY: 1
                  DOCKER_CERT_PATH: "$DOCKER_TLS_CERTDIR/client"
                before_script:
                  - |
                    echo "Waiting for docker to start..."
                    for i in $(seq 1 30); do
                      docker info && break
                      sleep 1s
                    done
                script:
                  - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
                  - docker build -t $IMAGE_TAG .
                  - docker push $IMAGE_TAG
            YAML
          }
        ])

        create(:project_wiki_page,
          api_client: admin_api_client,
          project: project,
          title: 'Wiki',
          content: content) # 10.2 KiB

        create(:project_snippet,
          api_client: admin_api_client,
          project: project,
          title: 'Snippet to move storage of',
          file_name: 'original_file',
          file_content: content)
      end

      after do
        endpoint = QA::Runtime::API::Request.new(admin_api_client, '/application/settings').url

        put endpoint, { namespace_aggregation_schedule_lease_duration_in_seconds: 300 }
      ensure
        free_plan_group.remove_via_api!
      end

      def convert_to_mib(size)
        unit = 'KiB'
        amount = size.split(' ')[0].to_f

        if size.include? unit
          amount / 1024
        else
          amount
        end
      end

      def within_a_tenth?(size_displayed, size)
        # NOTE: On the UI the numbers are generally displayed with `.round(1)`. We are testing that
        # the sizes that we have extracted from the UI are within this rounding error margin.
        # Different magnitudes (KiB/MiB/GiB) would give us different margins of errors. Currently we
        # have only one MiB value, and three KiB magnitude values. So the total possible offset
        # should be within 0.1 MiB range.
        (size_displayed - size).abs <= 0.1
      end

      context 'in usage quotas storage tab for free plan with a project' do
        it(
          'shows correct used up storage for namespace'
        ) do
          project.visit!
          Flow::Pipeline.visit_latest_pipeline

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.click_job('container-registry')
          end

          Page::Project::Job::Show.perform do |job|
            expect(job).to be_successful(timeout: 800)
          end

          free_plan_group.visit!

          Runtime::Feature.enable(:namespace_storage_limit, group: free_plan_group)

          Page::Group::Menu.perform(&:go_to_usage_quotas)

          EE::Page::Group::Settings::UsageQuotas.perform do |usage_quota|
            usage_quota.click_storage_tab

            aggregate_failures do
              expect(usage_quota.project_repository_size).to match(%r{\d+\.?\d+ [KMG]?i?B})
              expect(usage_quota.project_snippets_size).to match(%r{\d+\.?\d+ [KMG]?i?B})
              expect(usage_quota.project_wiki_size).to match(%r{\d+\.?\d+ [KMG]?i?B})
              expect(usage_quota.project_containers_registry_size).to match(%r{\d+\.?\d+ [KMG]?i?B})

              repository_size = convert_to_mib(usage_quota.project_repository_size) # 41.0 KiB
              snippets_size = convert_to_mib(usage_quota.project_snippets_size) # 10.2 KiB
              wiki_size = convert_to_mib(usage_quota.project_wiki_size) # 10.2 KiB
              # NOTE: containers_registry_size value depends on the actual docker image size and
              # apparently can fluctuate. Currently it's ~ 50 MiB, give or take
              containers_registry_size = convert_to_mib(usage_quota.project_containers_registry_size)
              total_size = repository_size + snippets_size + wiki_size + containers_registry_size

              expect do
                ::QA::Support::WaitForRequests.wait_for_requests # Handle element loading text
                usage_quota.namespace_usage_total.squish
              end
                .to eventually_match(
                  %r{Namespace storage used (#{total_size.floor}|#{total_size.ceil})\.\d+ [KMG]iB.+}i
                )
                .within(max_duration: 300, reload_page: page)

              namespace_usage_total_text = usage_quota.namespace_usage_total.squish
              total_size_displayed = namespace_usage_total_text[/Namespace storage used (\d+\.\d+)/, 1].to_f
              expect(within_a_tenth?(total_size_displayed, total_size)).to be_truthy,
                "Expected displayed total size: #{total_size_displayed} " \
                  "to be within a tenth of total size: #{total_size}"
              expect(usage_quota.dependency_proxy_size).to match(%r{0 B}i)
              expect(usage_quota.group_usage_message)
                .to match(%r{Usage of group resources across the projects in the #{free_plan_group.path} group}i)
            end
          end
        end
      end
    end
  end
end
