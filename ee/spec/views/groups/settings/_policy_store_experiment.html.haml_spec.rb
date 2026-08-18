# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_policy_store_experiment.html.haml', feature_category: :security_policy_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group, namespace_settings: build_stubbed(:namespace_settings)) }

  let(:form) { instance_double(Gitlab::FormBuilders::GitlabUiFormBuilder) }
  let(:licensed) { true }
  let(:instance_enabled) { true }
  let(:feature_flag_enabled) { true }

  before do
    stub_feature_flags(security_policies_v2: feature_flag_enabled)
    allow(view).to receive_messages(group: group, current_user: user, f: form)
    allow(group).to receive(:licensed_feature_available?).with(:security_orchestration_policies).and_return(licensed)
    stub_application_setting(policy_store_experiment_enabled: instance_enabled)
  end

  context 'when the feature flag is enabled, licensed, and instance-enabled' do
    it 'renders the toggle' do
      expect(form).to receive(:gitlab_ui_checkbox_component).with(:policy_store_experiment_enabled, anything)

      render

      expect(rendered).to render_template('groups/settings/_policy_store_experiment')
    end
  end

  context 'when the security_policies_v2 feature flag is disabled' do
    let(:feature_flag_enabled) { false }

    it 'renders nothing' do
      render

      expect(rendered).to be_empty
    end
  end

  context 'when the license is unavailable' do
    let(:licensed) { false }

    it 'renders nothing' do
      render

      expect(rendered).to be_empty
    end
  end

  context 'when the instance setting is off' do
    let(:instance_enabled) { false }

    it 'renders nothing' do
      render

      expect(rendered).to be_empty
    end
  end

  context 'when the group is a subgroup' do
    before do
      allow(group).to receive(:root?).and_return(false)
    end

    it 'renders nothing, as the experiment is top-level-group only' do
      render

      expect(rendered).to be_empty
    end
  end
end
