# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipeline', :js, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace) }

  before do
    sign_in(user)
    project.add_developer(user) # -- Does not work in before_all
  end

  describe 'GET /:project/-/pipelines/:id' do
    let(:pipeline) { create(:ci_pipeline, :with_job, project: project, ref: 'master', sha: project.commit.id, user: user) }

    subject { visit project_pipeline_path(project, pipeline) }

    context 'triggered and triggered by pipelines' do
      let(:upstream_pipeline) { create(:ci_pipeline, :with_job) }
      let(:downstream_pipeline) { create(:ci_pipeline, :with_job) }

      before do
        upstream_pipeline.project.add_developer(user)
        downstream_pipeline.project.add_developer(user)

        create_link(upstream_pipeline, pipeline)
        create_link(pipeline, downstream_pipeline)
      end

      context 'expands the upstream pipeline on click' do
        it 'renders upstream pipeline' do
          subject

          expect(page).to have_content(upstream_pipeline.id)
          expect(page).to have_content(upstream_pipeline.project.name)
        end

        it 'expands the upstream on click' do
          subject

          page.find(".js-pipeline-expand-#{upstream_pipeline.id}").click
          wait_for_requests
          expect(page).to have_selector("#pipeline-links-container-#{upstream_pipeline.id}")
        end

        it 'closes the expanded upstream on click' do
          subject

          # open
          page.find(".js-pipeline-expand-#{upstream_pipeline.id}").click
          wait_for_requests

          # close
          page.find(".js-pipeline-expand-#{upstream_pipeline.id}").click

          expect(page).not_to have_selector("#pipeline-links-container-#{upstream_pipeline.id}")
        end
      end

      it 'renders downstream pipeline' do
        subject

        expect(page).to have_content(downstream_pipeline.id)
        expect(page).to have_content(downstream_pipeline.project.name)
      end

      context 'expands the downstream pipeline on click' do
        it 'expands the downstream on click' do
          subject

          page.find(".js-pipeline-expand-#{downstream_pipeline.id}").click
          wait_for_requests
          expect(page).to have_selector("#pipeline-links-container-#{downstream_pipeline.id}")
        end

        it 'closes the expanded downstream on click' do
          subject

          # open
          page.find(".js-pipeline-expand-#{downstream_pipeline.id}").click
          wait_for_requests

          # close
          page.find(".js-pipeline-expand-#{downstream_pipeline.id}").click

          expect(page).not_to have_selector("#pipeline-links-container-#{downstream_pipeline.id}")
        end
      end
    end

    describe 'identity verification requirement', :saas do
      include IdentityVerificationHelpers

      let_it_be(:user) { create(:user, :identity_verification_eligible) }

      before do
        stub_saas_features(identity_verification: true)
      end

      shared_examples 'does not show an alert prompting the user to verify their account' do
        it 'does not show an alert prompting the user to verify their account' do
          subject

          expect(page).not_to have_content('Before you can run pipelines, we need to verify your account.')
        end
      end

      it_behaves_like 'does not show an alert prompting the user to verify their account'

      context 'when pipeline failed with user_not_verified status' do
        let_it_be(:pipeline) do
          create(
            :ci_empty_pipeline,
            project: project,
            ref: 'master',
            status: 'failed',
            failure_reason: 'user_not_verified',
            sha: project.commit.id,
            user: user
          )
        end

        it 'prompts the user to verify their account', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/467777' do
          subject

          expect(page).to have_content('Before you can run pipelines, we need to verify your account.')

          click_on 'Verify my account'

          wait_for_requests

          expect_to_see_identity_verification_page

          solve_arkose_verify_challenge

          verify_phone_number

          click_link 'Next'

          wait_for_requests

          expect(page).not_to have_content('Before you can run pipelines, we need to verify your account.')
        end
      end
    end

    describe 'pipeline stats text' do
      let_it_be_with_reload(:finished_pipeline) do
        create(:ci_pipeline, :success, project: project,
          ref: 'master', sha: project.commit.id, user: user)
      end

      before do
        finished_pipeline.update!(started_at: "2023-01-01 01:01:05", created_at: "2023-01-01 01:01:01",
          finished_at: "2023-01-01 01:01:10", duration: 9)
      end

      context 'pipeline has finished and has compute minutes' do
        it 'shows pipeline compute minutes and time ago' do
          allow_next_found_instance_of(Ci::Pipeline) do |pipeline|
            allow(pipeline).to receive(:total_ci_minutes_consumed).and_return 25
          end

          visit project_pipeline_path(project, finished_pipeline)

          within_testid('pipeline-header') do
            expect(find_by_testid('compute-minutes')).to have_content("25")
            expect(page).to have_selector('[data-testid="compute-minutes"]')
            expect(page).to have_selector('[data-testid="pipeline-finished-time-ago"]')
          end
        end
      end

      context 'pipeline has not finished and does not have compute minutes' do
        it 'does not show pipeline compute minutes and time ago' do
          subject

          within_testid('pipeline-header') do
            expect(page).not_to have_selector('[data-testid="compute-minutes"]')
            expect(page).not_to have_selector('[data-testid="pipeline-finished-time-ago"]')
          end
        end
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/security' do
    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before do
      stub_licensed_features(sast: true, security_dashboard: true)
      stub_feature_flags(pipeline_security_dashboard_graphql: false)
    end

    context 'with a sast artifact' do
      before do
        create(:ee_ci_build, :sast, pipeline: pipeline)
        visit security_project_pipeline_path(project, pipeline)
      end

      it 'shows security tab pane as active' do
        expect(page).to have_content('Security')
        expect(page).to have_selector('[data-testid="security-tab"]')
      end

      it 'shows security dashboard' do
        expect(page).to have_css('[data-testid="pipeline-vulnerability-report"]')
      end
    end

    context 'without sast artifact' do
      before do
        visit security_project_pipeline_path(project, pipeline)
      end

      it 'displays the pipeline graph' do
        expect(page).to have_current_path(pipeline_path(pipeline), ignore_query: true)
        expect(page).not_to have_selector('[data-testid="security-tab"]')
        expect(page).to have_selector('.js-pipeline-graph')
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/licenses' do
    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before do
      stub_licensed_features(license_scanning: true)
    end

    context 'with CycloneDX artifacts' do
      before do
        create(:ee_ci_build, :cyclonedx, pipeline: pipeline)
        create(:pm_package_version_license, :with_all_relations, name: "activesupport", purl_type: "gem",
          version: "5.1.4", license_name: "MIT")
        create(:pm_package_version_license, :with_all_relations, name: "github.com/sirupsen/logrus",
          purl_type: "golang", version: "v1.4.2", license_name: "MIT")
        create(:pm_package_version_license, :with_all_relations, name: "github.com/sirupsen/logrus",
          purl_type: "golang", version: "v1.4.2", license_name: "BSD-3-Clause")
        create(:pm_package_version_license, :with_all_relations, name: "org.apache.logging.log4j/log4j-api",
          purl_type: "maven", version: "2.6.1", license_name: "BSD-3-Clause")
        create(:pm_package_version_license, :with_all_relations, name: "yargs", purl_type: "npm", version: "11.1.0",
          license_name: "unknown")

        visit licenses_project_pipeline_path(project, pipeline)
      end

      it 'shows license tab pane as active' do
        expect(page).to have_content('Licenses')
        expect(page).to have_selector('[data-testid="license-tab"]')
        expect(find_by_testid('license-tab')).to have_content('4')
      end

      it 'shows security report section', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9306' do
        expect(page).to have_content('Loading License compliance report')
      end
    end

    context 'without CycloneDX artifacts' do
      before do
        visit licenses_project_pipeline_path(project, pipeline)
      end

      it 'displays the pipeline graph' do
        expect(page).to have_current_path(pipeline_path(pipeline), ignore_query: true)
        expect(page).not_to have_content('Licenses')
        expect(page).to have_selector('.js-pipeline-graph')
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/codequality_report', :aggregate_failures do
    shared_examples_for 'full codequality report' do
      context 'when licensed' do
        before do
          stub_licensed_features(full_codequality_report: true)
        end

        context 'with code quality artifact' do
          before do
            create(:ee_ci_build, :codequality, pipeline: pipeline)
          end

          context 'when navigating directly to the code quality tab' do
            before do
              visit codequality_report_project_pipeline_path(project, pipeline)
            end

            it_behaves_like 'an active code quality tab'
          end

          context 'when starting from the pipeline tab' do
            before do
              visit project_pipeline_path(project, pipeline)
            end

            it 'shows the code quality tab as inactive' do
              expect(page).to have_content('Code Quality')
              expect(page).not_to have_css('#js-tab-codequality')
            end

            context 'when the code quality tab is clicked' do
              before do
                click_link 'Code Quality'
              end

              it_behaves_like 'an active code quality tab'
            end
          end
        end

        context 'with no code quality artifact' do
          before do
            create(:ee_ci_build, pipeline: pipeline)
            visit project_pipeline_path(project, pipeline)
          end

          it 'does not show code quality tab' do
            expect(page).not_to have_content('Code Quality')
            expect(page).not_to have_css('#js-tab-codequality')
          end
        end
      end

      context 'when unlicensed' do
        before do
          stub_licensed_features(full_codequality_report: false)

          create(:ee_ci_build, :codequality, pipeline: pipeline)
          visit project_pipeline_path(project, pipeline)
        end

        it 'does not show code quality tab' do
          expect(page).not_to have_content('Code Quality')
          expect(page).not_to have_css('#js-tab-codequality')
        end
      end
    end

    shared_examples_for 'an active code quality tab' do
      it 'shows code quality tab pane as active, quality issue with link to file, and events for data tracking' do
        expect(page).to have_content('Code Quality')

        expect(page).to have_content('Method new_array has 12 arguments (exceeds 4 allowed). Consider refactoring.')
        expect(find_link('foo.rb:10')[:href]).to end_with(project_blob_path(project, File.join(pipeline.commit.id, 'foo.rb')) + '#L10')

        expect(page).to have_selector('[data-track-action="click_button"]')
        expect(page).to have_selector('[data-track-label="get_codequality_report"]')
      end
    end

    context 'for a branch pipeline' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

      it_behaves_like 'full codequality report'
    end

    context 'for a merge request pipeline' do
      let(:merge_request) do
        create(:merge_request,
          :with_merge_request_pipeline,
          source_project: project,
          target_project: project,
          merge_sha: project.commit.id)
      end

      let(:pipeline) do
        merge_request.all_pipelines.last
      end

      it_behaves_like 'full codequality report'
    end
  end

  private

  def create_link(source_pipeline, pipeline)
    source_pipeline.sourced_pipelines.create!(
      source_job: source_pipeline.builds.all.sample,
      source_project: source_pipeline.project,
      project: pipeline.project,
      pipeline: pipeline
    )
  end
end
