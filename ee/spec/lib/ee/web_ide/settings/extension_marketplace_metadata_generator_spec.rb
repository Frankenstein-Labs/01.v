# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe WebIde::Settings::ExtensionMarketplaceMetadataGenerator, feature_category: :web_ide do
  using RSpec::Parameterized::TableSyntax

  let(:marketplace_home_url) { "https://example.com" }
  let(:user_class) do
    stub_const(
      "User",
      Class.new do
        def flipper_id
          "UserStub"
        end
      end
    )
  end

  let(:group_class) { stub_const('Namespace', Class.new) }
  let(:user) { user_class.new }
  let(:group) { group_class.new }
  let(:input_context) do
    {
      requested_setting_names: [:vscode_extension_marketplace_metadata],
      options: {
        user: user
      },
      settings: {
        vscode_extension_marketplace_home_url: marketplace_home_url
      }
    }
  end

  subject(:actual_settings) do
    described_class.generate(input_context).dig(:settings, :vscode_extension_marketplace_metadata)
  end

  where(
    :enterprise_group,
    :enterprise_group_enabled,
    :expectation
  ) do
    nil | false | { enabled: false, disabled_reason: :opt_in_unset }
    ref(:group) | false | { enabled: false, disabled_reason: :enterprise_group_disabled }
    ref(:group) | true  | { enabled: false, disabled_reason: :opt_in_unset }
  end

  with_them do
    before do
      # note: Leaving user's opt_in unset so we can test that the CE checks are still running
      allow(user).to receive_messages(
        enterprise_user?: !!enterprise_group,
        enterprise_group: enterprise_group,
        extensions_marketplace_opt_in_status: 'unset',
        extensions_marketplace_opt_in_url: marketplace_home_url
      )
      allow(group).to receive(:enterprise_users_extensions_marketplace_enabled?).and_return(enterprise_group_enabled)

      allow(::WebIde::ExtensionMarketplace).to receive(:feature_enabled_from_application_settings?)
        .and_return(true)
    end

    it "adds settings with disabled reason based on enterprise_group presence and setting" do
      expect(actual_settings).to eq(expectation)
    end
  end
end
