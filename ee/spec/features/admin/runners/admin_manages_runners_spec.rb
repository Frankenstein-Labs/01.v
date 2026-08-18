# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin manages runners in admin runner list', :js, feature_category: :fleet_visibility do
  include RunnerReleasesHelper
  include Features::RunnersHelpers

  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'version management' do
    let_it_be(:runner) { create(:ci_runner) }
    let_it_be(:runner_manager) { create(:ci_runner_machine, runner: runner, version: '15.0.0') }

    let(:upgrade_status) { :unavailable }
    let!(:runner_version) { create(:ci_runner_version, version: '15.0.0', status: upgrade_status) }

    shared_examples 'upgrade is recommended' do
      it 'shows an orange upgrade recommended icon' do
        within_runner_row(runner.id) do
          expect(page).to have_selector '.gl-text-warning[data-testid="upgrade-icon"]'
        end
      end
    end

    shared_examples 'upgrade is available' do
      it 'shows a blue upgrade available icon' do
        within_runner_row(runner.id) do
          expect(page).to have_selector '.gl-text-blue-500[data-testid="upgrade-icon"]'
        end
      end
    end

    shared_examples 'no upgrade shown' do
      it 'shows no upgrade icon' do
        within_runner_row(runner.id) do
          expect(page).not_to have_selector '[data-testid="upgrade-icon"]'
        end
      end
    end

    context 'with runner_upgrade_management enabled' do
      before do
        stub_licensed_features(runner_upgrade_management: true)

        visit admin_runners_path
      end

      describe 'recommended to upgrade' do
        let(:upgrade_status) { :recommended }

        it_behaves_like 'upgrade is recommended'

        context 'when filtering "up to date"' do
          before do
            input_filtered_search_filter_is_only(s_('Runners|Upgrade Status'), s_('Runners|Up to date'))
          end

          it_behaves_like 'shows no runners found'
        end
      end

      describe 'available to upgrade' do
        let(:upgrade_status) { :available }

        it_behaves_like 'upgrade is available'
      end

      describe 'no upgrade available' do
        let(:upgrade_status) { :unavailable }

        it_behaves_like 'no upgrade shown'
      end
    end

    shared_examples 'runner upgrade disabled' do
      describe 'filters' do
        let(:upgrade_status) { :unavailable }

        it 'does not show upgrade filter' do
          focus_filtered_search

          page.within(search_bar_selector) do
            expect(page).not_to have_link(s_('Runners|Upgrade Status'))
          end
        end
      end

      describe 'can upgrade' do
        let(:upgrade_status) { :available }

        it_behaves_like 'no upgrade shown'
      end
    end

    context 'with runner_upgrade_management licensed feature is disabled' do
      before do
        stub_licensed_features(runner_upgrade_management: false)

        visit admin_runners_path
      end

      it_behaves_like 'runner upgrade disabled'
    end

    context 'when fetching runner releases setting is disabled' do
      before do
        stub_application_setting(update_runner_versions_enabled: false)

        visit admin_runners_path
      end

      it_behaves_like 'runner upgrade disabled'
    end
  end

  describe 'fleet dashboard link' do
    context 'with runner_performance_insights licensed feature' do
      before do
        stub_licensed_features(runner_performance_insights: true)

        visit admin_runners_path
      end

      it 'shows dashboard link' do
        expect(page).to have_link s_('Runners|Fleet dashboard'), href: dashboard_admin_runners_path
      end

      it 'shows dashboard' do
        visit dashboard_admin_runners_path

        within_testid('breadcrumb-links') do
          expect(page).to have_link('Fleet dashboard')
        end
      end
    end

    context 'without runner_performance_insights licensed feature' do
      before do
        stub_licensed_features(runner_performance_insights: false)

        visit admin_runners_path
      end

      it 'shows no dashboard link' do
        expect(page).not_to have_link(href: dashboard_admin_runners_path)
      end
    end
  end
end
