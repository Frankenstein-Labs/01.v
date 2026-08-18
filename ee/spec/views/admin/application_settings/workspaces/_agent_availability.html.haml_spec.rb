# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_workspaces_agent_availability', feature_category: :workspaces do
  let_it_be(:organization) { build_stubbed(:organization) }
  let_it_be(:user) { build_stubbed(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  # We use `view.render`, because just `render` throws a "no implicit conversion of nil into String" exception
  # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/53093#note_499060593
  subject(:rendered) { view.render('admin/application_settings/workspaces/agent_availability') }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive_messages(
      current_user: user,
      expanded_by_default?: true
    )
    ::Current.organization = organization
  end

  [true, false].each do |license_enabled|
    context "when license is #{license_enabled ? 'enabled' : 'disabled'}" do
      before do
        stub_licensed_features(remote_development: license_enabled)
      end

      it "#{license_enabled ? 'renders' : 'does not render'} settings" do
        if license_enabled
          expect(rendered).to have_selector('#js-workspaces-agent-availability-settings')
        else
          expect(rendered).to be_nil
        end
      end
    end
  end

  context 'when settings is rendered' do
    before do
      stub_licensed_features(remote_development: true)
    end

    it { is_expected.to have_selector("[data-organization-id='#{organization.id}']") }
    it { is_expected.to have_selector("[data-default-expanded='true']") }
  end
end
