# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe WebIde::Settings::ExtensionMarketplaceViewModelGenerator, feature_category: :web_ide do
  let(:user_class) { stub_const('User', Class.new) }
  let(:group_class) { stub_const('Group', Class.new) }
  let(:user) { user_class.new }
  let(:group) { group_class.new }
  let(:requested_setting_names) { [:vscode_extension_marketplace_view_model] }
  let(:vscode_extension_marketplace) { { item_url: 'https://example.com/vscode/is/cooler/than/rubymine' } }
  let(:vscode_extension_marketplace_metadata) { { enabled: true } }

  let(:context) do
    {
      requested_setting_names: requested_setting_names,
      settings: {
        vscode_extension_marketplace: vscode_extension_marketplace,
        vscode_extension_marketplace_metadata: vscode_extension_marketplace_metadata
      },
      options: {
        user: user
      }
    }
  end

  let(:expected_help_url) { a_string_matching('/help/user/project/web_ide/_index.md#manage-extensions') }

  before do
    allow(user).to receive(:enterprise_group).and_return(group)
    allow(group).to receive_messages(
      full_name: 'Test Enterprise Group',
      to_param: '/groups/test-group'
    )

    # why: Stubs necessary for fast_spec_helper. See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/167495#note_2290309350
    # The `spec/lib/web_ide/extension_marketplace_spec.rb` covers everything in integration, so we should be good.
    allow(::Gitlab::Routing).to receive_message_chain(:url_helpers, :profile_preferences_url)
      .with(anchor: 'integrations')
      .and_return('http://gdk.test/profile_preferences_url#integrations')

    allow(::Gitlab::Routing).to receive_message_chain(:url_helpers, :help_page_url)
      .with('user/project/web_ide/_index.md', anchor: 'manage-extensions')
      .and_return('http://gdk.test/help_url')

    allow(::Gitlab::Routing).to receive_message_chain(:url_helpers, :group_url)
      .with(group)
      .and_return('http://gdk.test/group_url')
  end

  describe '.generate' do
    subject(:settings_result) do
      described_class.generate(context).dig(:settings, :vscode_extension_marketplace_view_model)
    end

    context 'when metadata is disabled for instance_disabled' do
      let(:vscode_extension_marketplace_metadata) { { enabled: false, disabled_reason: :instance_disabled } }

      it 'does not include group info in the setting' do
        expect(settings_result).not_to include(:enterprise_group_name, :enterprise_group_url)
        expect(settings_result).to match({
          enabled: false,
          reason: :instance_disabled,
          help_url: 'http://gdk.test/help_url'
        })
      end
    end

    context 'when metadata is disabled for enterprise_group_disabled' do
      let(:vscode_extension_marketplace_metadata) { { enabled: false, disabled_reason: :enterprise_group_disabled } }

      it 'includes group info in the setting' do
        expect(settings_result).to match({
          enabled: false,
          reason: :enterprise_group_disabled,
          help_url: 'http://gdk.test/help_url',
          enterprise_group_name: 'Test Enterprise Group',
          enterprise_group_url: 'http://gdk.test/group_url'
        })
      end
    end
  end
end
