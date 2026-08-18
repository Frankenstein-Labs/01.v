# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_ee_package_registry.html.haml', feature_category: :package_registry do
  let_it_be(:user) { build(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  let(:forward_package_text) do
    s_(
      'PackageRegistry|Forward package requests to a public registry if the packages are not found in the ' \
      'GitLab package registry.'
    )
  end

  let(:security_risks_text) do
    s_('PackageRegistry|There are security risks if packages are deleted while request forwarding is enabled.')
  end

  let(:risks_link) do
    help_page_path('user/packages/package_registry/supported_functionality.md', { anchor: 'deleting-packages' })
  end

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  shared_examples 'rendering package forwarding settings' do
    before do
      stub_licensed_features(package_forwarding: feature_avaliable)
    end

    it 'checks package forwarding settings' do
      render

      if feature_avaliable
        expect(rendered).to have_content(forward_package_text)
        expect(rendered).to have_content(security_risks_text)
        expect(rendered).to have_link('What are the risks?', href: risks_link)
      else
        expect(rendered).not_to have_content(forward_package_text)
        expect(rendered).not_to have_content(security_risks_text)
        expect(rendered).not_to have_link('What are the risks?', href: risks_link)
      end
    end
  end

  describe 'package registry settings' do
    context 'when package forwarding feature is available' do
      let(:feature_avaliable) { true }

      it_behaves_like 'rendering package forwarding settings'
    end

    context 'when package forwarding feature is not available' do
      let(:feature_avaliable) { false }

      it_behaves_like 'rendering package forwarding settings'
    end
  end

  describe 'nuget url validation' do
    let(:header) { _('Skip metadata URL validation for the NuGet package') }
    let(:checkbox_selector) { 'input[name="application_setting[nuget_skip_metadata_url_validation]"]' }

    it 'shows skip nuget url validation checkbox' do
      render

      expect(rendered).to have_content(header)
      expect(rendered).to have_selector(checkbox_selector)
    end

    context 'when on gitlab.com', :saas do
      it 'does not show skip nuget url validation checkbox' do
        render

        expect(rendered).not_to have_content(header)
        expect(rendered).not_to have_selector(checkbox_selector)
      end
    end
  end
end
