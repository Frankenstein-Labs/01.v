# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/groups/new', feature_category: :onboarding do
  let(:google_tag_manager_id) { 'GTM-WWKMTWS' }

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }

  before do
    assign(:group, group)
    assign(:project, project)
    stub_config(extra:
                  {
                    google_tag_manager_id: google_tag_manager_id,
                    google_tag_manager_nonce_id: google_tag_manager_id
                  })
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:import_sources_enabled?).and_return(false)
    allow(view).to receive(:tracking_label).and_return('free_registration')
  end

  context 'when Google Tag Manager is enabled' do
    before do
      allow(view).to receive(:google_tag_manager_enabled?).and_return(true)
      render
    end

    subject { rendered }

    it 'contains a Google Tag Manager tag' do
      is_expected.to match(/www.googletagmanager.com/)
    end
  end

  context 'when Google Tag Manager is disabled' do
    before do
      allow(view).to receive(:google_tag_manager_enabled?).and_return(false)
      render
    end

    subject { rendered }

    it 'does not contain a Google Tag Manager tag' do
      is_expected.not_to match(/www.googletagmanager.com/)
    end
  end

  describe 'page title' do
    before do
      allow(view).to receive(:page_title)
    end

    it 'sets the correct page title' do
      render

      expect(view).to have_received(:page_title).with(_('Create or import your first project'))
    end
  end

  context 'for form action path' do
    subject { render && rendered }

    it do
      is_expected.to have_css('form[action="/users/sign_up/groups"]')
    end
  end

  context 'with expected DOM elements' do
    it 'contains js-groups-projects-form class' do
      render

      expect(rendered).to have_css('.js-groups-projects-form')
    end

    it 'has project creation form tabs' do
      render

      expect(rendered).to have_css('.js-toggle-container')
      expect(rendered).to have_css('#blank-project-pane')
      expect(rendered).to have_css('#import-project-pane')
    end
  end
end
