# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_security_policies.html.haml', feature_category: :security_policy_management do
  let(:app_settings) { build(:application_setting) }

  before do
    assign(:application_setting, app_settings)
  end

  context 'when security_policies_v2 is enabled' do
    it 'renders the Policy Store experiment toggle' do
      render

      expect(rendered).to have_content('Allow Policy Store experiment for groups')
    end
  end

  context 'when security_policies_v2 is disabled' do
    before do
      stub_feature_flags(security_policies_v2: false)
    end

    it 'does not render the Policy Store experiment toggle' do
      render

      expect(rendered).not_to have_content('Allow Policy Store experiment for groups')
    end
  end
end
