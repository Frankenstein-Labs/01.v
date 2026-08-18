# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::HookLogsController, feature_category: :webhooks do
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:web_hook) { create(:group_hook) }
  let_it_be_with_refind(:web_hook_log) { create(:web_hook_log, web_hook: web_hook) }

  let_it_be(:group) { web_hook.group }

  it_behaves_like WebHooks::HookLogActions do
    let(:edit_hook_path) { edit_group_hook_url(group, web_hook) }

    before_all do
      group.add_owner(user)
    end
  end

  context 'with a custom role' do
    let_it_be(:role) { create(:member_role, :guest, :admin_web_hook) }
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like WebHooks::HookLogActions do
      let(:edit_hook_path) { edit_group_hook_url(group, web_hook) }
    end
  end
end
