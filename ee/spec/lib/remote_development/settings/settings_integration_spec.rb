# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::Settings, feature_category: :workspaces do # rubocop:disable RSpec/SpecFilePathFormat -- This cop fails because the spec is named 'settings_integration_spec.rb' but describes ::RemoteDevelopment::Settings class. But we want it that way, because it's an integration spec, not a unit spec, but we still want to be able to use `described_class`
  subject(:settings_module) { described_class }

  context "when there is no override" do
    it "uses default value" do
      expect(settings_module.get_single_setting(:default_branch_name)).to be_nil
    end
  end

  context "when there is an env var override" do
    before do
      stub_env("GITLAB_REMOTE_DEVELOPMENT_MAX_ACTIVE_HOURS_BEFORE_STOP", "46")
    end

    it "uses the env var override value and casts it" do
      expect(settings_module.get_single_setting(:max_active_hours_before_stop)).to eq(46)
    end
  end

  context "when there is an env var override and production env" do
    before do
      stub_env("GITLAB_REMOTE_DEVELOPMENT_MAX_ACTIVE_HOURS_BEFORE_STOP", "46")
      allow(Rails).to receive_message_chain(:env, :production?) { true }
    end

    it "does not use the env var override value and use default value" do
      expect(settings_module.get_single_setting(:max_active_hours_before_stop)).to eq(36)
    end
  end

  context "when there is a ::Gitlab::CurrentSettings override" do
    let(:overridden_setting_value_from_current_settings) { "value_from_current_settings" }
    let(:current_settings_class) do
      # NOTE: We intentionally do not attempt to make this test use the real `ApplicationSetting` class with
      # `stub_application_setting`, because this resulted in occasional cache-related test failures in
      # `CurrentSettings.respond_to?` for `ApplicationSetting` fields which are in the process of being deprecated.
      double( # rubocop:disable RSpec/VerifiedDoubles -- We don't care about using a verified double here, this is a mix of class and dynamic stubbed methods.
        "Gitlab::CurrentSettings",
        respond_to?: true,
        default_branch_name: overridden_setting_value_from_current_settings
      )
    end

    before do
      stub_const("Gitlab::CurrentSettings", current_settings_class)
    end

    it "uses the CurrentSettings value" do
      # fixture sanity check
      expect(Gitlab::CurrentSettings.default_branch_name).to eq(overridden_setting_value_from_current_settings)

      expect(settings_module.get_single_setting(:default_branch_name))
        .to eq(overridden_setting_value_from_current_settings)
    end
  end

  context "when there is a ::Gitlab.config override" do
    let(:overridden_setting_value_from_gitlab_config) { "value_from_gitlab config" }

    before do
      allow(Gitlab).to receive_message_chain(:config, :gitlab_kas, :external_url) do
        overridden_setting_value_from_gitlab_config
      end
    end

    it "uses the ENV var value and not the Gitlab.config value" do
      expect(settings_module.get_single_setting(:gitlab_kas_external_url))
        .to eq(overridden_setting_value_from_gitlab_config)
    end
  end

  context "when there is an ENV var override and also a ::Gitlab::CurrentSettings override" do
    let(:override_value_from_env) { "value_from_env" }
    let(:overridden_setting_value_from_current_settings) { "value_from_current_settings" }
    let(:current_settings_class) do
      # NOTE: We intentionally do not attempt to make this test use the real `ApplicationSetting` class with
      # `stub_application_setting`, because this resulted in occasional cache-related test failures in
      # `CurrentSettings.respond_to?` for `ApplicationSetting` fields which are in the process of being deprecated.
      double( # rubocop:disable RSpec/VerifiedDoubles -- We don't care about using a verified double here, this is a mix of class and dynamic stubbed methods.
        "Gitlab::CurrentSettings",
        respond_to?: true,
        default_branch_name: overridden_setting_value_from_current_settings
      )
    end

    before do
      stub_env("GITLAB_REMOTE_DEVELOPMENT_DEFAULT_BRANCH_NAME", override_value_from_env)

      stub_const("Gitlab::CurrentSettings", current_settings_class)
    end

    it "uses the ENV var value and not the CurrentSettings value" do
      # fixture sanity check
      expect(Gitlab::CurrentSettings.default_branch_name).to eq(overridden_setting_value_from_current_settings)

      expect(settings_module.get_single_setting(:default_branch_name)).to eq(override_value_from_env)
    end
  end

  context "when passed an invalid setting name" do
    it "raises an error" do
      expect { settings_module.get_single_setting(:invalid_setting_name) }
        .to raise_error("Unsupported setting name(s): invalid_setting_name")
    end
  end
end
