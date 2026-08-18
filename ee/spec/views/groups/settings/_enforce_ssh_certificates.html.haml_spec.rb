# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_enforce_ssh_certificates.html.haml', feature_category: :source_code_management do
  let_it_be(:group) { build_stubbed(:group, namespace_settings: build_stubbed(:namespace_settings)) }

  before do
    allow(view).to receive(:group).and_return(group)
  end

  context 'when ssh certificates feature is unavailable' do
    it 'does not render enforce SSH certificates settings' do
      render

      expect(rendered).to be_empty
    end
  end

  context 'when ssh certificates feature is available' do
    it 'renders enforce SSH certificates settings' do
      form = instance_double('Gitlab::FormBuilders::GitlabUiFormBuilder')
      allow(view).to receive(:can?).and_return(true)
      allow(view).to receive(:f).and_return(form)
      allow(group).to receive(:ssh_certificates_available?).and_return(true)

      expect(form).to receive(:gitlab_ui_checkbox_component).with(:enforce_ssh_certificates, anything)

      render

      expect(rendered).to render_template('groups/settings/_enforce_ssh_certificates')
      expect(rendered).to have_content('Enforce SSH Certificates')
    end
  end
end
