# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Settings > User changes default branch', feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, namespace: user.namespace) }
  let_it_be_with_reload(:protected_branch) do
    create(:protected_branch, project: project, name: project.default_branch)
  end

  let(:default_branch_settings) { find('#default-branch-settings') }
  let(:default_branch_button) do
    within_testid('default-branch-dropdown') do
      find('button')
    end
  end

  let(:visit_repository_page) { visit project_settings_repository_path(project) }

  before do
    sign_in(user)
  end

  context 'with branch not protected by security policy' do
    it 'does not show popover if the default branch can be changed', :aggregate_failures, :js do
      visit_repository_page

      expect(default_branch_settings).not_to have_selector('[data-toggle="popover"]')
      expect(default_branch_button).not_to be_disabled
    end
  end

  context 'with branch protected by security policy' do
    include_context 'with approval policy blocking protected branches' do
      let(:branch_name) { project.default_branch }
      let(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      it 'disables the button and shows the popover if the default branch cannot be changed',
        :aggregate_failures,
        :js do
        visit_repository_page

        expect(default_branch_settings).to have_selector('[data-toggle="popover"]')

        # `be_disabled` reads the native property, which a Pajamas button no longer sets: it
        # renders `aria-disabled` to stay focusable. Capybara's `:button` filter knows both.
        within_testid('default-branch-dropdown') do
          expect(page).to have_button(disabled: true)
        end
      end
    end
  end
end
