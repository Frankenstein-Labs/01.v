# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NotificationRecipients::Builder::Default, feature_category: :team_planning do
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:sub_group) { create(:group, :public, parent: group) }

  let_it_be(:current_user) { create(:user) }

  let_it_be(:group_watcher) do
    create(:user).tap { |u| create(:notification_setting, source: group, user: u, level: 2) }
  end

  let_it_be(:sub_group_watcher) do
    create(:user).tap { |u| create(:notification_setting, source: sub_group, user: u, level: 2) }
  end

  let_it_be(:custom_notification_user) do
    create(:user).tap { |u| create(:notification_setting, source: sub_group, user: u, level: :custom, new_epic: true) }
  end

  let_it_be(:target) { create(:work_item, :epic, namespace: sub_group, author: current_user) }

  subject(:builder) { described_class.new(target, current_user, action: :new).tap(&:build!) }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#build!' do
    it 'adds watchers and custom notification users to the recipients' do
      expect(builder.notification_recipients.map(&:user)).to contain_exactly(
        group_watcher,
        sub_group_watcher,
        custom_notification_user
      )
    end
  end
end
