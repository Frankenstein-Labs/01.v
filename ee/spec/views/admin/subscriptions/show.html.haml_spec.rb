# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/subscriptions/show.html.haml', feature_category: :subscription_management do
  context 'for duo_amazon_q_alert' do
    before do
      allow(view).to receive(:current_user).and_return(build_stubbed(:user))
      stub_saas_features(subscriptions_trials: false)
      allow(GitlabSubscriptions::DuoAmazonQ)
        .to receive(:any_add_on_purchase).and_return(build_stubbed(:gitlab_subscription_add_on_purchase))

      render
    end

    subject { view.content_for(:page_level_alert) }

    it { is_expected.to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }
  end
end
