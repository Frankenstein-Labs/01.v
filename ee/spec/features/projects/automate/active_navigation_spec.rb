# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Automate sidebar active navigation', :js, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_developer(user)
  end

  before do
    sign_in(user)

    # Rendering the page checks usage billing against CustomersDot.
    allow_next_instance_of(::Ai::UsageQuotaService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success)
    end
  end

  # Regression test for https://gitlab.com/gitlab-org/gitlab/-/work_items/607982:
  # these sidebar items are highlighted exclusively by the SPA's global
  # `beforeEach` guard (their server-side `active_routes` is nil), which the
  # Vue Router compat shim skipped on the initial navigation.
  it 'marks the sidebar item for the current route as active on initial load' do
    visit project_automate_agents_path(project)

    within '#super-sidebar' do
      expect(page).to have_css('a.selected[href$="/-/automate/agents"]')
    end
  end
end
