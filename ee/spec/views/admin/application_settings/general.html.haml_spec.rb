# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/general.html.haml' do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  subject { rendered }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'maintenance mode' do
    let(:license_allows) { true }

    before do
      allow(Gitlab::Geo).to receive(:license_allows?).and_return(license_allows)

      render
    end

    context 'when license does not allow' do
      let(:license_allows) { false }

      it 'does not show the Maintenance mode section' do
        expect(rendered).not_to have_css('#js-maintenance-mode-toggle')
      end
    end

    context 'when license allows' do
      it 'shows the Maintenance mode section' do
        expect(rendered).to have_css('#js-maintenance-mode-toggle')
      end
    end
  end

  describe 'SAML group locks settings' do
    let(:saml_group_sync_enabled) { false }
    let(:settings_text) { 'SAML group membership settings' }

    before do
      allow(view).to receive(:saml_group_sync_enabled?).and_return(saml_group_sync_enabled)

      render
    end

    it { is_expected.not_to match(settings_text) }

    context 'when one or multiple SAML providers are group-sync-enabled' do
      let(:saml_group_sync_enabled) { true }

      it { is_expected.to match(settings_text) }
    end
  end

  describe 'prompt user about registration features' do
    context 'with no license and service ping disabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'renders registration features prompt', :application_setting_disabled_repository_size_limit
      it_behaves_like 'renders registration features settings link'
    end

    context 'with a valid license and service ping disabled' do
      let(:current_license) { build(:license) }

      before do
        allow(License).to receive(:current).and_return(current_license)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'does not render registration features prompt', :application_setting_disabled_repository_size_limit
    end
  end

  describe 'add license' do
    let(:current_license) { build(:license) }

    before do
      assign(:new_license, current_license)
      render
    end

    it 'shows the Add License section' do
      expect(rendered).to have_css('#js-add-license-toggle')
    end
  end

  describe 'sign-up restrictions' do
    it 'includes signup_form_data' do
      allow(view).to receive(:signup_form_data).and_return({ the_answer: '42' })

      render

      expect(rendered).to match 'data-the-answer="42"'
    end

    it 'does not render complexity setting attributes' do
      render

      expect(rendered).to match 'id="js-signup-form"'
      expect(rendered).not_to match 'data-password-lowercase-required'
    end

    context 'when password_complexity license is available' do
      before do
        stub_licensed_features(password_complexity: true)
      end

      it 'renders complexity setting attributes' do
        render

        expect(rendered).to match ' data-password-lowercase-required='
        expect(rendered).to match ' data-password-number-required='
      end
    end
  end

  describe 'private profile restrictions', feature_category: :user_management do
    it 'renders correct ee partial' do
      render

      expect(rendered).to render_template('admin/application_settings/_private_profile_restrictions')
    end
  end

  describe 'AmazonQ settings', feature_category: :ai_abstraction_layer do
    it 'renders correct ee partial' do
      render

      expect(rendered).to render_template('admin/application_settings/_amazon_q')
    end

    describe 'Disable group invite members settings', feature_category: :groups_and_projects do
      it 'renders correct partial' do
        render

        expect(rendered).to render_template('admin/application_settings/_disable_invite_members_setting')
      end
    end
  end

  describe 'Workspaces agent availability settings', feature_category: :workspaces do
    it 'renders correct ee partial' do
      render

      expect(rendered).to render_template('admin/application_settings/workspaces/_agent_availability')
    end
  end
end
