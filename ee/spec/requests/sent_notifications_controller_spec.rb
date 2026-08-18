# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentNotificationsController, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'GET #unsubscribe' do
    context 'when user is authenticated' do
      let_it_be(:user) { create(:user, developer_of: group) }

      before do
        sign_in(user)
        stub_licensed_features(epics: true)
      end

      context 'when sent_notifications belongs to a group level issue' do
        let_it_be(:issue) { create(:issue, :group_level, namespace: group) }
        let_it_be(:sent_notification) { create(:sent_notification, project: nil, noteable: issue, recipient: user) }

        it 'unsubscribes and redirects to issue path' do
          get unsubscribe_namespace_sent_notification_path(sent_notification.namespace_id, sent_notification)

          expect(response).to redirect_to("/groups/#{group.path}/-/work_items/#{issue.iid}")
        end
      end
    end
  end
end
