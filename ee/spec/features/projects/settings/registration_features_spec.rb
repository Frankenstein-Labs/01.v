# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project settings > [EE] registration features', :js, :enable_admin_mode, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:admin) }

  let(:registration_features_message) do
    format(
      s_('RegistrationFeatures|Want to %{feature_title} for free?'),
      feature_title: s_('RegistrationFeatures|use this feature')
    )
  end

  before do
    sign_in(user)
  end

  describe 'prompt user about registration features' do
    context 'with no license and service ping disabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_application_setting(usage_ping_enabled: false)
        visit edit_project_path(project)
      end

      it 'renders registration features prompt with settings link' do
        expect(page).to have_field('project_disabled_repository_size_limit', disabled: true)
        expect(page).to have_content(registration_features_message)
        expect(page).to have_link(s_('RegistrationFeatures|Registration Features Program'))
        expect(page).to have_link(s_('RegistrationFeatures|Enable Service Ping and register for this feature.'))
      end
    end

    context 'with a valid license and service ping disabled' do
      before do
        allow(License).to receive(:current).and_return(build(:license))
        stub_application_setting(usage_ping_enabled: false)
        visit edit_project_path(project)
      end

      it 'does not render registration features prompt' do
        # Wait for the Vue form to render before asserting the prompt is absent.
        expect(page).to have_field('project_name_edit')

        expect(page).not_to have_field('project_disabled_repository_size_limit', disabled: true)
        expect(page).not_to have_content(registration_features_message)
        expect(page).not_to have_link(s_('RegistrationFeatures|Registration Features Program'))
      end
    end
  end
end
