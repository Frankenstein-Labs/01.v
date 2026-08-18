# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/_ultimate_with_enterprise_trial_callout_content.html.haml', feature_category: :acquisition do
  let(:user) { build_stubbed(:user) }

  let(:partial) { 'shared/ultimate_with_enterprise_trial_callout_content' }

  before do
    allow(view).to receive_messages(current_user: user, trial_duration: 60)
  end

  it 'renders the trial banner content' do
    render partial

    expect(rendered).to have_content('Free Ultimate Trial with GitLab Duo Enterprise')
    expect(rendered).to have_link(
      'Start your free trial',
      href: new_trial_path(glm_source: Gitlab.config.gitlab.host, glm_content: 'gold-callout')
    )
  end

  it 'renders the dismissible callout' do
    render partial

    expect(rendered).to have_dismissible_callout(feature_id: 'ultimate_trial')
  end

  context 'when the user dismissed the callout' do
    let(:user) do
      build_stubbed(:user, callouts: [build_stubbed(:callout, feature_name: 'ultimate_trial')])
    end

    it 'does not render the banner' do
      render partial

      expect(rendered).not_to have_content('Free Ultimate Trial with GitLab Duo Enterprise')
    end
  end
end
