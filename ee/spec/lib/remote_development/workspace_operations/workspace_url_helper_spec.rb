# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::WorkspaceUrlHelper, feature_category: :workspaces do
  let(:name) { "name" }
  let(:port) { 1234 }
  let(:dns_zone) { "example.dns.zone" }
  let(:gitlab_workspaces_proxy_http_enabled) { true }
  let(:url_prefix) { "#{port}-#{name}" }
  let(:url_query_string) { { example: "/value" }.to_query }
  let(:host_suffix) { dns_zone }
  let(:expected_url_template) { "${PORT}-name.example.dns.zone" }
  let(:expected_url) { "https://1234-name.example.dns.zone/?example=%2Fvalue" }

  subject(:returned_value) do
    url_template = described_class.url_template(name, dns_zone, gitlab_workspaces_proxy_http_enabled)
    url = described_class.url(url_prefix, url_query_string, dns_zone, gitlab_workspaces_proxy_http_enabled)
    common_workspace_host_suffix = described_class.common_workspace_host_suffix?(gitlab_workspaces_proxy_http_enabled)
    workspace_host_suffix = described_class.workspace_host_suffix(dns_zone, gitlab_workspaces_proxy_http_enabled)

    {
      url_template: url_template,
      url: url,
      common_workspace_host_suffix: common_workspace_host_suffix,
      workspace_host_suffix: workspace_host_suffix
    }
  end

  it "uses dns_zone for workspace_url" do
    expect(returned_value).to eq(
      {
        url_template: expected_url_template,
        url: expected_url,
        common_workspace_host_suffix: false,
        workspace_host_suffix: dns_zone
      }
    )
  end

  describe "when gitlab_workspaces_proxy_http_enabled is set to false" do
    let(:gitlab_workspaces_proxy_http_enabled) { false }

    before do
      stub_config(workspaces: gitlab_config_workspaces)
    end

    context "when gitlab config is set correctly" do
      let(:gitlab_config_workspaces_host) { "config.workspaces.host:1234" }
      let(:expected_url_template) { "${PORT}-name.config.workspaces.host:1234" }
      let(:expected_url) { "https://1234-name.config.workspaces.host:1234/?example=%2Fvalue" }
      let(:gitlab_config_workspaces) { { enabled: true, host: gitlab_config_workspaces_host } }

      it "uses gitlab config workspace host for workspace_url" do
        expect(returned_value).to eq(
          {
            url_template: expected_url_template,
            url: expected_url,
            common_workspace_host_suffix: true,
            workspace_host_suffix: gitlab_config_workspaces_host
          }
        )
      end
    end

    context "when gitlab config is set incorrectly" do
      let(:gitlab_config_workspaces) { { enabled: false } }

      it "uses dns_zone for workspace_url" do
        expect(returned_value).to eq(
          {
            url_template: expected_url_template,
            url: expected_url,
            common_workspace_host_suffix: false,
            workspace_host_suffix: dns_zone
          }
        )
      end
    end
  end
end
