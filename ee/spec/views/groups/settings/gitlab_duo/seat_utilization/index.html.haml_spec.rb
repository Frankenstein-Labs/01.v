# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/gitlab_duo/seat_utilization/index', feature_category: :ai_abstraction_layer do
  let(:group) { build(:group) }

  before do
    assign(:group, group)
    allow(view)
      .to receive_messages(can_invite_group_member?: true, current_user_mode: Gitlab::Auth::CurrentUserMode.new(nil))
  end

  it 'renders the settings app root with the correct data attributes', :aggregate_failures do
    render template: 'groups/settings/gitlab_duo/seat_utilization/index', layout: 'layouts/group'

    expect(rendered).to have_selector('#js-gitlab-duo-usage-settings')
    expect(rendered).to have_selector('.js-invite-members-modal[data-reload-page-on-submit="true"]')
  end
end
