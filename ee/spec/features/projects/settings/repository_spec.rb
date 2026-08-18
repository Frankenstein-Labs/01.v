# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE Project Repository settings', :js, feature_category: :source_code_management do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  before do
    sign_in(user)
  end

  shared_examples "does not show the settings section" do
    it 'does not show the setting section' do
      expect(page).not_to have_selector('#js-general-settings')
    end
  end

  context 'in General subsection' do
    context 'when web-based commit signing is available',
      :saas_repositories_web_based_commit_signing do
      context 'when group has web-based commit signing disabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: false)
          visit project_settings_repository_path(project)
          wait_for_requests
        end

        it 'shows the setting section' do
          expect(page).to have_selector('#js-general-settings')
        end

        it 'shows web-based commit signing section as unchecked and enabled' do
          expect(page).to have_css('[data-testid="web-based-commit-signing-checkbox"]')
          expect(page).to have_unchecked_field('Sign web-based commits', disabled: false)
        end

        it 'persists the checkbox value after checking and reloading' do
          expect(page).to have_unchecked_field('Sign web-based commits')

          check 'Sign web-based commits'
          wait_for_requests
          expect(page).to have_checked_field('Sign web-based commits')

          visit project_settings_repository_path(project)
          wait_for_requests
          expect(page).to have_checked_field('Sign web-based commits')
        end

        context 'when project has web-based commit signing enabled' do
          before do
            project.project_setting.update!(web_based_commit_signing_enabled: true)
            visit project_settings_repository_path(project)
            wait_for_requests
          end

          it 'shows web-based commit signing section as checked and enabled' do
            expect(page).to have_css('[data-testid="web-based-commit-signing-checkbox"]')
            expect(page).to have_checked_field('Sign web-based commits', disabled: false)
          end
        end
      end

      context 'when group has web-based commit signing enabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: true)
          group.reload
          visit project_settings_repository_path(project)
          wait_for_requests
        end

        it 'shows web-based commit signing section as checked and disabled (inherited from group)' do
          expect(page).to have_css('[data-testid="web-based-commit-signing-checkbox"]')
          expect(page).to have_checked_field('Sign web-based commits', disabled: true)
        end
      end
    end

    context 'when SaaS feature is not available' do
      before do
        stub_saas_features(repositories_web_based_commit_signing: false)
        visit project_settings_repository_path(project)
        wait_for_requests
      end

      it_behaves_like "does not show the settings section"
    end
  end
end
