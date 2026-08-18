# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User adds a merge request to a merge train', :sidekiq_inline, :js, feature_category: :merge_trains do
  let(:project) { create(:project, :repository) }
  let(:user) { project.owner }

  let!(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:ci_yaml) do
    { test: { stage: 'test', script: 'echo', only: ['merge_requests'] } }
  end

  before do
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(200)
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    stub_ci_pipeline_yaml_file(YAML.dump(ci_yaml))

    allow_next_found_instance_of(ProjectCiCdSetting) do |setting|
      allow(setting).to receive_messages(merge_pipelines_enabled: true, merge_trains_enabled: true)
    end

    sign_in(user)
  end

  context 'when no active pipeline' do
    before do
      merge_request.all_pipelines.first.succeed!
      merge_request.update_head_pipeline
    end

    it "shows 'Merge' button with 'Add to merge train' helper text" do
      visit project_merge_request_path(project, merge_request)

      expect(page).to have_button('Merge')
      expect(page).to have_content('Add to merge train')
    end

    context 'when merge_trains EEP license is not available' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      it 'does not show Add to merge train helper text' do
        visit project_merge_request_path(project, merge_request)

        expect(page).not_to have_content('Add to merge train')
      end
    end

    context "when user clicks 'Merge' button to add to merge train" do
      before do
        visit project_merge_request_path(project, merge_request)
        click_button 'Merge'
        wait_for_requests
      end

      it 'shows merge request is added to merge train',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/471562' do
        page.within('.mr-state-widget') do
          expect(page).to have_content("Added to the merge train by #{user.name}")
          expect(page).to have_content('Source branch will not be deleted.')
          expect(page).to have_button('Remove from merge train')
        end
      end

      context 'when pipeline for merge train succeeds' do
        let(:project) { create(:project, :repository) }
        let(:user) { project.owner }

        before do
          visit project_merge_request_path(project, merge_request)
          wait_for_requests
          merge_request.merge_train_car.pipeline.builds.map(&:success!)
        end

        it 'displays the expected content', :js,
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/2152' do
          expect(page).to have_selector('[data-testid="pipeline-mini-graph-dropdown"]')

          find_by_testid('pipeline-mini-graph-dropdown-toggle').click
          page.within '.ci-job-component' do
            expect(page).to have_selector('[data-testid="ci-icon"]')
            expect(page).not_to have_selector('.retry')
          end

          expect(page).to have_content("Merged")
        end
      end

      context "when user clicks 'Remove from merge train' button" do
        before do
          click_button 'Remove from merge train'
        end

        it 'cancels automatic merge',
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9454' do
          page.within('.mr-state-widget') do
            expect(page).not_to have_content("Added to the merge train by #{user.name}")
            expect(page).to have_button('Merge')
            expect(page).to have_content('Add to merge train')
          end
        end
      end
    end

    context 'when the merge request is not the first queue on the train',
      quarantine: {
        issue: [
          'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/12628',
          'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24090'
        ]
      } do
      before do
        create(:merge_request, :on_train,
          source_project: project, source_branch: 'signed-commits',
          target_project: project, target_branch: 'master')
      end

      it "shows 'Merge' button and 'Add to merge train' helper text" do
        visit project_merge_request_path(project, merge_request)

        expect(page).to have_button('Merge')
        expect(page).to have_content('Add to merge train')
      end
    end
  end

  context 'with an active pipeline' do
    before do
      merge_request.all_pipelines.first.run!
      merge_request.update_head_pipeline
    end

    it "shows 'Merge' button with 'Add to merge train when all merge checks pass' helper text" do
      visit project_merge_request_path(project, merge_request)

      expect(page).to have_button('Merge')
      expect(page).to have_content('Add to merge train when all merge checks pass')
    end

    context 'when merge_trains EEP license is not available',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/12630' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      it "does not show 'Add to merge train when all merge checks pass' helper text" do
        visit project_merge_request_path(project, merge_request)

        expect(page).not_to have_content('Add to merge train when all merge checks pass')
      end
    end

    context "when user clicks 'Add to merge train when all merge checks pass' button",
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/12629' do
      before do
        visit project_merge_request_path(project, merge_request)
        click_button 'Set to auto-merge'
        wait_for_requests
      end

      it 'shows merge request will be added to merge train when all merge checks pass' do
        page.within('.mr-state-widget') do
          expect(page).to have_content("Set by #{user.name} to start a merge train when all merge checks pass")
          expect(page).to have_content('Source branch will not be deleted.')
          expect(page).to have_button('Cancel auto-merge')
        end
      end

      context 'when pipeline succeeds' do
        before do
          merge_request.head_pipeline.succeed!
          visit project_merge_request_path(project, merge_request)
          wait_for_requests
        end

        it 'adds the MR to the merge train but not yet merged' do
          expect(page).to have_content("Added to the merge train by #{user.name}")
          expect(page).to have_content('Source branch will not be deleted.')
          expect(page).to have_button('Remove from merge train')

          expect(page).not_to have_content("Merged")
        end

        context 'when the merge train pipeline passes' do
          let(:project) { create(:project, :repository) }
          let(:user) { project.owner }

          it 'merges the MR' do
            merge_request.merge_train_car.pipeline.builds.map(&:success!)

            expect(page).to have_selector('[data-testid="pipeline-mini-graph-dropdown"]')

            find_by_testid('pipeline-mini-graph-dropdown-toggle').click
            page.within '.ci-job-component' do
              expect(page).to have_selector('[data-testid="ci-icon"]')
              expect(page).not_to have_selector('.retry')
            end

            expect(page).to have_content("Merged")
          end
        end
      end

      context "when user clicks 'Cancel auto-merge' button" do
        before do
          click_button 'Cancel auto-merge'
        end

        it 'cancels automatic merge' do
          wait_for_requests

          page.within('.mr-state-widget') do
            expect(page).not_to have_content("Set by #{user.name} to start a merge train when all merge checks pass")
            expect(page).to have_button('Set to auto-merge')
          end
        end
      end
    end
  end
end
