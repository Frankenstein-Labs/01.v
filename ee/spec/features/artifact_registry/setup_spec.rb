# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization Artifact Registry setup page', :js, :with_current_organization,
  feature_category: :artifact_registry do
  let_it_be(:user) { create(:organization_owner, organization: current_organization).user }

  before do
    sign_in(user)
  end

  it 'renders the claim form for an owner', :aggregate_failures do
    visit artifact_registry_organization_index_path(current_organization)

    expect(page).to have_testid('page-heading', text: 'Set up Artifact registry')
    expect(page).to have_field('artifact-registry-handle', placeholder: 'my-registry')
    # The frontend builds the client base URL from the origin of `api_url` alone
    # (ADR-009), so this compares against the configured value only because the test
    # config sets it as a bare origin. The derivation itself is covered in
    # ee/spec/helpers/organizations/artifact_registry_helper_spec.rb.
    expect(find_by_testid('handle-url-prefix'))
      .to have_content("#{Gitlab.config.artifact_registry['api_url']}/")

    expect(page).to be_axe_clean.within_testid('artifact-registry-setup')
  end
end
