# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHookLogPolicy, feature_category: :webhooks do
  describe 'read_web_hook and admin_web_hook' do
    context 'when the webhook log belongs to a group hook' do
      let_it_be(:web_hook) { create(:group_hook) }
      let_it_be(:authorized_user) { create(:user, owner_of: web_hook.group) }
      let_it_be(:unauthorized_user) { create(:user, maintainer_of: web_hook.group) }

      it_behaves_like 'a webhook log policy'
    end
  end
end
