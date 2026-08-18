# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User sees Security Configuration table', :js, feature_category: :dynamic_application_security_testing do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, maintainers: user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  before do
    sign_in(user)
    create(:callout, user: user, feature_name: :security_scanner_profiles_announcement)
  end

  context 'with security_dashboard feature available' do
    before do
      stub_licensed_features(
        security_dashboard: true,
        sast: true,
        sast_advanced: true,
        sast_iac: true,
        dast: true,
        dependency_scanning: true,
        container_scanning: true,
        coverage_fuzzing: true,
        api_fuzzing: true,
        security_configuration_in_ui: true,
        secret_push_protection: true
      )
    end

    context 'enabling SAST' do
      let(:test_data_sast_string_fields_array) do
        [
          %w[SECURE_ANALYZERS_PREFIX registry.example.com],
          ['SAST_EXCLUDED_PATHS', 'foo, bar']
        ]
      end

      let(:test_data_int_fields_array) do
        [
          %w[SEARCH_MAX_DEPTH 42]
        ]
      end

      it 'shows SAST' do
        visit_configuration_page

        within_sast_card do
          expect(page).to have_text('SAST')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Enable SAST')

          click_on 'Enable SAST'

          expect(page).to have_current_path("/#{project.full_path}/-/security/configuration/sast", ignore_query: true)
        end

        fill_sast_fields(test_data_sast_string_fields_array)
        fill_sast_fields(test_data_int_fields_array)

        click_button('Create merge request')

        expect(page).to have_current_path(project_new_merge_request_path(project), ignore_query: true)

        find_by_testid('diffs-tab').click

        test_data_sast_string_fields_array.each do |key, value|
          expect(page).to have_content("#{key}: #{value}")
        end

        test_data_int_fields_array.each do |field_type, field_value|
          expect(page).to have_content("#{field_type}: '#{field_value}'")
        end
      end
    end

    context 'with SAST report' do
      before do
        create(:ci_build, :sast, name: 'semgrep-sast', pipeline: pipeline, status: 'success')
      end

      it 'shows SAST is enabled' do
        visit_configuration_page

        within_sast_card do
          expect(page).to have_text('SAST')
          expect(page).to have_text('Enabled')
          expect(page).to have_button('Configure SAST')
        end
      end
    end

    context 'enabling SAST Advanced' do
      it 'shows SAST Advanced' do
        visit_configuration_page

        within_sast_advanced_card do
          expect(page).to have_text('Advanced SAST')
          expect(page).not_to have_button('Configure with a merge request')
        end
      end
    end

    context 'enabling SAST IaC' do
      it 'redirects to new MR page' do
        visit_configuration_page

        within_sast_iac_card do
          expect(page).to have_text('Infrastructure as Code (IaC) Scanning')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Configure with a merge request')

          click_button 'Configure with a merge request'

          expect(page).to have_current_path(project_new_merge_request_path(project), ignore_query: true)
        end
      end
    end

    context 'with no DAST report' do
      it 'shows DAST is not enabled' do
        visit_configuration_page

        within_dast_card do
          expect(page).to have_text('DAST')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Enable DAST')
        end
      end
    end

    context 'with DAST report' do
      before do
        create(:ci_build, :dast, pipeline: pipeline, status: 'success')
      end

      it 'shows DAST is enabled' do
        visit_configuration_page

        within_dast_card do
          expect(page).to have_text('DAST')
          expect(page).to have_text('Enabled')
          expect(page).to have_button('Configure DAST')
          expect(page).to have_link('Manage DAST profiles')
        end
      end
    end

    context 'with no Dependency Scanning report' do
      it 'shows Dependency Scanning is disabled' do
        visit_configuration_page

        within_dependency_scanning_card do
          expect(page).to have_text('Dependency Scanning')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Configure with a merge request')
        end
      end
    end

    context 'with Dependency Scanning report' do
      before do
        create(:ci_build, :dependency_scanning, pipeline: pipeline, status: 'success')
      end

      it 'shows Dependency Scanning is enabled' do
        visit_configuration_page

        within_dependency_scanning_card do
          expect(page).to have_text('Dependency Scanning')
          expect(page).to have_text('Enabled')
          expect(page).to have_link('Configuration guide')
        end
      end
    end

    context 'with no Container Scanning report' do
      it 'shows Container Scanning is disabled' do
        visit_configuration_page

        within_container_scanning_card do
          expect(page).to have_text('Container Scanning')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Configure with a merge request')
        end
      end
    end

    context 'without Secret Push Protection' do
      it 'shows secret push protection disabled' do
        visit_configuration_page

        within_secret_push_protection_card do
          expect(page).to have_text('Secret push protection')
          expect(page).to have_text('Restricted by administrator')

          toggle = find_by_testid('toggle-wrapper')
          expect(toggle).to have_css("button:not(.is-checked)")
          expect(toggle).to have_css('.is-disabled')
        end
      end
    end

    context 'with Secret push protection' do
      before do
        stub_application_setting(secret_push_protection_available: true)
      end

      it 'shows secret push protection' do
        visit_configuration_page

        within_secret_push_protection_card do
          expect(page).to have_text('Secret push protection')
          expect(page).to have_text('Not enabled')

          toggle = find_by_testid('toggle-wrapper')
          expect(toggle).to have_css("button:not(.is-checked)")
          expect(toggle).not_to have_css('.is-disabled')

          toggle.find('button').click

          expect(page).to have_text('Enabled')
          expect(toggle).to have_css("button.is-checked")
        end
      end
    end

    context 'with no Pipeline Secret Detection report' do
      it 'shows Pipeline Secret Detection is disabled' do
        visit_configuration_page

        within_pipeline_secret_detection_card do
          expect(page).to have_text('Pipeline Secret Detection')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Configure with a merge request')
        end
      end
    end

    context 'with no API Fuzzing report' do
      it 'shows API Fuzzing is disabled' do
        visit_configuration_page

        within_api_fuzzing_card do
          expect(page).to have_text('API Fuzzing')
          expect(page).to have_text('Not enabled')
          expect(page).to have_button('Enable API Fuzzing')
        end
      end
    end

    context 'with no Coverage Fuzzing' do
      it 'shows Coverage Fuzzing is disabled' do
        visit_configuration_page

        within_coverage_fuzzing_card do
          expect(page).to have_text('Coverage Fuzzing')
          expect(page).to have_text('Not enabled')
          expect(page).to have_link('Configuration guide')
        end
      end
    end
  end

  def visit_configuration_page
    visit(project_security_configuration_path(project))
  end

  def fill_sast_fields(array)
    array.each do |key, value|
      element = find("[data-testid='#{key}-field']")
      page.execute_script("arguments[0].innerHTML = ''", element.native)
      element.set(value)
    end
  end

  def within_security_testing_card(title)
    within_testid('security-testing-tab') do
      within_testid('security-testing-features') do
        card = find("[data-testid='security-testing-card'] h3", text: title, exact_text: true)
                 .ancestor("[data-testid='security-testing-card']")

        within(card) { yield }
      end
    end
  end

  def within_sast_card
    within_security_testing_card('Static Application Security Testing (SAST)') { yield }
  end

  def within_sast_advanced_card
    within_security_testing_card('GitLab Advanced SAST') { yield }
  end

  def within_sast_iac_card
    within_security_testing_card('Infrastructure as Code (IaC) Scanning') { yield }
  end

  def within_dast_card
    within_security_testing_card('Dynamic Application Security Testing (DAST)') { yield }
  end

  def within_dependency_scanning_card
    within_security_testing_card('Dependency Scanning') { yield }
  end

  def within_container_scanning_card
    within_security_testing_card('Container Scanning') { yield }
  end

  def within_secret_push_protection_card
    within_security_testing_card('Secret push protection') { yield }
  end

  def within_pipeline_secret_detection_card
    within_security_testing_card('Pipeline Secret Detection') { yield }
  end

  def within_coverage_fuzzing_card
    within_security_testing_card('Coverage Fuzzing') { yield }
  end

  def within_api_fuzzing_card
    within_security_testing_card('API Fuzzing') { yield }
  end
end
