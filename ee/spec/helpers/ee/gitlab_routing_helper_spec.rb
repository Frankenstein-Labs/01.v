# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::GitlabRoutingHelper, feature_category: :shared do
  include ProjectsHelper
  include ApplicationSettingsHelper
  include EE::GeoHelpers

  let_it_be_with_reload(:primary) do
    create(
      :geo_node,
      :primary,
      url: 'http://localhost:123/relative',
      internal_url: 'http://internal:321/relative',
      clone_url_prefix: 'git@localhost:'
    )
  end

  let_it_be_with_reload(:group) { create(:group, path: 'foo') }
  let_it_be_with_reload(:project) { create(:project, namespace: group, path: 'bar') }

  describe '#geo_primary_web_url' do
    before do
      allow(helper).to receive(:default_clone_protocol).and_return('http')
    end

    context 'public / default URL' do
      it 'generates a path to the project' do
        result = helper.geo_primary_web_url(project)

        expect(result).to eq('http://localhost:123/relative/foo/bar')
      end

      it 'generates a path to the wiki' do
        result = helper.geo_primary_web_url(project.wiki)

        expect(result).to eq('http://localhost:123/relative/foo/bar.wiki')
      end
    end

    context 'internal URL' do
      it 'generates a path to the project' do
        result = helper.geo_primary_web_url(project, internal: true)

        expect(result).to eq('http://internal:321/relative/foo/bar')
      end

      it 'generates a path to the wiki' do
        result = helper.geo_primary_web_url(project.wiki, internal: true)

        expect(result).to eq('http://internal:321/relative/foo/bar.wiki')
      end
    end
  end

  describe '#geo_proxied_http_url_to_repo' do
    subject { helper.geo_proxied_http_url_to_repo(primary, repo) }

    let(:repo) { project }

    it { is_expected.to eq('http://localhost:123/relative/foo/bar.git') }
  end

  describe '#geo_proxied_ssh_url_to_repo' do
    subject { helper.geo_proxied_ssh_url_to_repo(proxied_site, primary_container) }

    let(:proxied_site) { instance_double(GeoNode, uri: URI::HTTP.build(host: 'proxied-host', port: 5678)) }
    let(:primary_container) { instance_double(Project, ssh_url_to_repo: ssh_url_to_repo) }

    before do
      stub_proxied_site(proxied_site)

      allow(Settings.gitlab).to receive(:host).and_return('primary-host')
    end

    context 'when ssh_port is customized' do
      let(:ssh_url_to_repo) { 'git@primary:bar.git' }

      before do
        stub_config(
          gitlab_shell: {
            ssh_port: 22,
            ssh_host: 'primary'
          }
        )
      end

      it { is_expected.to eq('git@primary:bar.git') }
    end

    context 'when ssh_port is the same as host' do
      let(:ssh_url_to_repo) { 'ssh://git@primary-host:123/bar.git' }

      before do
        stub_config(
          gitlab_shell: {
            ssh_port: 123,
            ssh_host: 'primary-host'
          }
        )
      end

      it { is_expected.to eq('ssh://git@proxied-host:123/bar.git') }
    end
  end

  describe '#geo_primary_default_url_to_repo' do
    subject { helper.geo_primary_default_url_to_repo(repo) }

    context 'HTTP' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('http')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq('http://localhost:123/relative/foo/bar.git') }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq('http://localhost:123/relative/foo/bar.wiki.git') }
      end
    end

    context 'HTTPS' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('https')
        primary.update!(url: 'https://localhost:123/relative')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq('https://localhost:123/relative/foo/bar.git') }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq('https://localhost:123/relative/foo/bar.wiki.git') }
      end
    end

    context 'SSH' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('ssh')
        allow(Gitlab.config.gitlab_shell).to receive(:ssh_user).and_return('git')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq("#{primary.clone_url_prefix}foo/bar.git") }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq("#{primary.clone_url_prefix}foo/bar.wiki.git") }
      end
    end
  end

  describe '#user_group_saml_omniauth_metadata_path' do
    subject(:metadata_path) do
      helper.user_group_saml_omniauth_metadata_path(group)
    end

    before do
      group.update!(saml_discovery_token: 'sometoken')
    end

    it 'uses metadata path' do
      expect(metadata_path).to start_with('/users/auth/group_saml/metadata')
    end

    it 'appends group path and token' do
      expect(metadata_path).to end_with('?group_path=foo&token=sometoken')
    end
  end

  describe '#user_group_saml_omniauth_metadata_url' do
    subject(:metadata_url) do
      helper.user_group_saml_omniauth_metadata_url(group)
    end

    it 'creates full metadata URL' do
      expect(metadata_url).to start_with 'http://localhost/users/auth/group_saml/metadata?group_path=foo&token='
    end
  end

  describe '#vulnerability_url' do
    let_it_be(:vulnerability) { create(:vulnerability) }

    subject(:vulnerability_link) { vulnerability_url(vulnerability) }

    it 'returns the full url of the vulnerability' do
      expect(vulnerability_link).to eq "http://localhost/#{vulnerability.project.full_path}/-/security/vulnerabilities/#{vulnerability.id}"
    end
  end

  describe '#usage_quotas_path' do
    it 'returns the group usage quota path for a group namespace' do
      group = build(:group)

      expect(usage_quotas_path(group)).to eq("/groups/#{group.full_path}/-/usage_quotas")
    end

    it 'returns the profile usage quotas path for any other namespace' do
      namespace = build(:namespace)

      expect(usage_quotas_path(namespace)).to eq('/-/profile/usage_quotas')
    end

    it 'returns the path with any args supplied' do
      namespace = build(:namespace)

      expect(usage_quotas_path(namespace, foo: 'bar', anchor: 'quotas-tab')).to eq('/-/profile/usage_quotas?foo=bar#quotas-tab')
    end
  end

  describe '#usage_quotas_url' do
    it 'returns the group usage quota url for a group namespace' do
      group = build(:group)

      expect(usage_quotas_url(group)).to eq("http://test.host/groups/#{group.full_path}/-/usage_quotas")
    end

    it 'returns the profile usage quotas url for any other namespace' do
      namespace = build(:namespace)

      expect(usage_quotas_url(namespace)).to eq('http://test.host/-/profile/usage_quotas')
    end

    it 'returns the url with any args supplied' do
      namespace = build(:namespace)

      expect(usage_quotas_url(namespace, foo: 'bar', anchor: 'quotas-tab')).to eq('http://test.host/-/profile/usage_quotas?foo=bar#quotas-tab')
    end
  end
end
