# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ::RemoteDevelopment::Settings::GitlabConfigReader, feature_category: :workspaces do
  include ResultMatchers

  let(:gitlab_kas_external_url_type) { String }

  let(:context) do
    {
      settings: {
        non_relevant_setting: "non_relevant",
        gitlab_kas_external_url: "default value"
      },
      setting_types: {
        non_relevant_setting: String,
        gitlab_kas_external_url: gitlab_kas_external_url_type
      }
    }
  end

  subject(:result) do
    described_class.read(context)
  end

  describe "gitlab_kas_external_url setting" do
    context "when config has a value set" do
      before do
        allow(Gitlab).to receive_message_chain(:config, :gitlab_kas, :external_url) { "value from file" }
      end

      it "returns the value" do
        expect(result).to be_ok_result(context)
        expect(result.unwrap[:settings][:gitlab_kas_external_url]).to eq("value from file")
      end
    end

    context "when config does not have a value set" do
      before do
        allow(Gitlab).to receive_message_chain(:config, :gitlab_kas).and_return(nil)
      end

      it "returns the value" do
        expect(result).to be_ok_result(context)
        expect(result.unwrap[:settings][:gitlab_kas_external_url]).to eq("default value")
      end
    end
  end

  context "when the type from GitLab.config does not match the declared remote development setting type" do
    let(:gitlab_kas_external_url_type) { Integer }

    it "returns an err Result containing a read failed message with details" do
      expect(result).to be_err_result(
        RemoteDevelopment::Settings::Messages::SettingsGitlabConfigReadFailed.new(
          details: "Gitlab.config.gitlab_kas_external_url type of 'String' " \
            "did not match initialized Remote Development Settings type of 'Integer'."
        )
      )
    end
  end
end
