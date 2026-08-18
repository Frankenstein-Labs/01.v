# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization Artifact Registry repositories SPA', :js, :with_current_organization,
  feature_category: :artifact_registry do
  let(:user) { create(:user, organizations: [current_organization]) }

  let(:slug) { ::Organizations::ArtifactRegistry::STUB_SLUG }
  let(:repositories_base_path) { "/o/#{current_organization.path}/-/artifact_registry/#{slug}/repositories" }
  let(:client) { instance_double(::ArtifactRegistry::Client) }

  before do
    sign_in(user)
  end

  it 'boots the Vue SPA shell on the slug-scoped repositories route' do
    visit repositories_base_path

    expect(page).to have_testid('repositories-shell')
  end

  it 'serves a deep unregistered sub-path via the Rails catch-all and renders the in-SPA NotFound fallback' do
    # The path reads as a repository name, so the route resolves and the page asks the server
    # whether that repository exists. Faking the client keeps the example independent of whether
    # an Artifact Registry is reachable, which decides between not-found and service-unavailable.
    allow(::ArtifactRegistry::Client).to receive(:new).with(current_user: user).and_return(client)
    allow(client).to receive(:repository).with(slug: slug, name: 'does-not-exist').and_return(nil)

    visit "#{repositories_base_path}/does-not-exist"

    within_testid('repositories-shell') do
      expect(page).to have_css('h1', text: 'Page not found')
    end
  end

  describe 'the repositories list' do
    # Faked at the client rather than over HTTP: the wire format is the client's own contract,
    # and these examples are about what the connection renders in a browser.
    let(:repositories_page) do
      ::ArtifactRegistry::Page.new(
        nodes: [
          ::ArtifactRegistry::Repository.new(
            'name' => 'maven-releases',
            'format' => 'maven',
            'kind' => 'hosted',
            'visibility' => 'private',
            'downloads_count' => 340,
            'size_bytes' => 2048,
            'last_updated_at' => '2026-07-02T11:30:00Z'
          )
        ]
      )
    end

    before do
      allow(::ArtifactRegistry::Client).to receive(:new).with(current_user: user).and_return(client)
      allow(client).to receive(:repositories).and_return(repositories_page)
    end

    it 'renders the page the connection returns' do
      visit repositories_base_path

      within_testid('repositories-shell') do
        expect(page).to have_css('h1', text: 'Repositories')
        expect(page).to have_link('maven-releases')
        expect(page).to have_content('Maven')
        expect(page).to have_content('Hosted')
        expect(page).to have_content('340')
        expect(page).to have_content('2.00 KiB')
      end
    end

    it 'passes axe automated accessibility testing' do
      visit repositories_base_path

      expect(page).to have_link('maven-releases')
      expect(page).to be_axe_clean.within_testid('repositories-shell')
    end
  end

  # The single-repository read the detail page and the edit form share. A green Jest suite cannot
  # speak for these two: their repository leaves the browser as a GraphQL document and comes back
  # resolved by the schema, so nothing short of a rendered page says which layer answered.
  # Nothing is asserted about the artifact list, which the browser still resolves for itself.
  describe 'a repository the schema resolves' do
    let(:name) { 'oci-repository' }
    let(:description) { 'Build artifacts for the payments domain.' }

    let(:repository) do
      ::ArtifactRegistry::Repository.new(
        'name' => name,
        'format' => 'maven',
        'kind' => 'hosted',
        'visibility' => 'private',
        'description' => description,
        'downloads_count' => 340,
        'size_bytes' => 2048,
        'last_updated_at' => '2026-07-02T11:30:00Z'
      )
    end

    before do
      allow(::ArtifactRegistry::Client).to receive(:new).with(current_user: user).and_return(client)
      allow(client).to receive(:repository).with(slug: slug, name: name).and_return(repository)
    end

    # The name deliberately says one format while the repository carries another, because the
    # front end guesses a format from the name wherever no read has resolved one. A page
    # rendering OCI here is one answering from that guess.
    it 'renders the detail page from the repository, not from the name' do
      visit "#{repositories_base_path}/#{name}"

      within_testid('repositories-shell') do
        expect(find_by_testid('repository-name')).to have_text(name)
        expect(find_by_testid('repository-format-name', visible: :all)).to have_text(:all, 'Maven')
        expect(page).to have_css('[data-testid="repository-visibility"][aria-label="Private"]')
        expect(find_by_testid('repository-description')).to have_text(description)
        expect(page).to have_content('Hosted')
      end
    end

    # No claim about what the artifact region holds, only that it settles: this is the one of its
    # three sentences that is neither the loading nor the service-unavailable message.
    it 'settles the artifact region rather than leaving it loading or failed' do
      visit "#{repositories_base_path}/#{name}"

      within_testid('repositories-shell') do
        expect(find_by_testid('artifacts-announcement', visible: :all))
          .to have_text(:all, 'Artifact list updated.')
      end
    end

    # Visibility is left out: the closed beta offers the single Private value, so its radio is
    # selected whether the read answered or not.
    it 'prefills the edit form from the repository' do
      visit "#{repositories_base_path}/#{name}/edit"

      within_testid('repositories-shell') do
        expect(page).to have_field(with: name, readonly: true)
        expect(page).to have_field(with: description, type: 'textarea')
        expect(page).to have_css('[data-testid="repository-format-logo"][src*="maven"]')
      end
    end
  end

  # The artifact route reads the same single repository, so whether it exists is Artifact
  # Registry's answer rather than the URL's. A page that rendered without asking would tell a
  # viewer a repository they cannot see is there. Nothing is asserted about the artifact itself,
  # which the browser still resolves for itself.
  describe 'an artifact of a repository Artifact Registry does not hold' do
    let(:name) { 'no-such-repository' }
    let(:artifact_id) { '01937b2e-0000-7000-8000-000000000001' }

    before do
      allow(::ArtifactRegistry::Client).to receive(:new).with(current_user: user).and_return(client)
    end

    it 'asks Artifact Registry for the repository and renders its not-found state' do
      expect(client).to receive(:repository).with(slug: slug, name: name).at_least(:once).and_return(nil)

      visit "#{repositories_base_path}/#{name}/#{artifact_id}"

      within_testid('repositories-shell') do
        expect(page).to have_css('h1', text: 'Page not found')
      end
    end
  end
end
