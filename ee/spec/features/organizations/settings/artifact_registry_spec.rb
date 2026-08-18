# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization Artifact Registry settings shell', :js, :with_current_organization,
  feature_category: :artifact_registry do
  let_it_be(:user) { create(:user, :organization_owner, organizations: [current_organization]) }

  before do
    sign_in(user)
  end

  it 'boots the Vue settings shell and renders the activation section' do
    visit artifact_registry_settings_organization_path(current_organization)

    expect(page).to have_content(s_('ArtifactRegistry|Activation'))
    expect(page).to have_content(
      s_('ArtifactRegistry|Control artifact registry access for this organization. When ' \
        'enabled, all projects and groups have access to a unified registry.')
    )
    expect_page_to_have_no_console_errors
  end

  describe 'the disable confirmation' do
    before do
      visit artifact_registry_settings_organization_path(current_organization)
    end

    # The section's action and the dialog's confirm button carry the same label, so the
    # lookup names the region it means rather than leaving the match to depend on which
    # of the two is rendered.
    def open_confirmation
      within_testid('artifact-registry-settings') do
        click_button s_('ArtifactRegistry|Disable Artifact Registry')
      end
    end

    it 'passes axe automated accessibility testing with the confirmation closed and open' do
      # The section reads the registry before it can offer an action, so the action is what
      # says the rendered state this scans has arrived.
      within_testid('artifact-registry-settings') do
        expect(page).to have_button(s_('ArtifactRegistry|Disable Artifact Registry'))
      end

      expect(page).to be_axe_clean.within_testid('artifact-registry-settings')

      open_confirmation

      expect(page).to have_css('[role="dialog"]')
      expect(page).to be_axe_clean.within('[role="dialog"]')
    end

    it 'takes focus, closes on Escape, and gives focus back to the action that opened it' do
      open_confirmation

      expect(page).to have_css('[data-testid="confirm-danger-field"]:focus')

      send_keys :escape

      expect(page).not_to have_css('[role="dialog"]')
      expect(page).to have_css('[data-testid="disable-registry"]:focus')
    end
  end
end
