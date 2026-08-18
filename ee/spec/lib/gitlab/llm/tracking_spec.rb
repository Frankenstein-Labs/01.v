# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Tracking, feature_category: :ai_abstraction_layer do
  let(:user) { build(:user) }
  let(:resource) { build(:project) }
  let(:ai_action_name) { 'chat' }
  let(:request_id) { 'uuid' }
  let(:user_agent) { nil }
  let(:platform_origin) { 'web' }

  let(:ai_message) do
    build(:ai_message,
      user: user,
      resource: resource,
      ai_action: ai_action_name,
      request_id: request_id,
      user_agent: user_agent,
      platform_origin: platform_origin
    )
  end

  describe '.event_for_ai_message' do
    subject(:event_for_ai_message) do
      described_class.event_for_ai_message('Category', 'my_action', ai_message: ai_message)
    end

    context 'when it is a web IDE request' do
      let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
      let(:platform_origin) { 'vs_code_extension' }

      it 'tracks event with web_ide client' do
        event_for_ai_message

        expect_snowplow_event(
          category: 'Category',
          action: 'my_action',
          label: ai_action_name,
          property: request_id,
          user: user,
          client: 'web_ide'
        )
      end
    end

    context 'when it is a regular web request' do
      let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
      let(:platform_origin) { 'web' }

      it 'tracks event with web client' do
        event_for_ai_message

        expect_snowplow_event(
          category: 'Category',
          action: 'my_action',
          label: ai_action_name,
          property: request_id,
          user: user,
          client: 'web'
        )
      end
    end

    context 'when it is a real VS Code extension request' do
      let(:user_agent) { 'vs-code-gitlab-workflow/3.11.1 VSCode/1.52.1 Node.js/12.14.1 (darwin; x64)' }
      let(:platform_origin) { 'vs_code_extension' }

      it 'tracks event with vscode client' do
        event_for_ai_message

        expect_snowplow_event(
          category: 'Category',
          action: 'my_action',
          label: ai_action_name,
          property: request_id,
          user: user,
          client: 'vscode'
        )
      end
    end
  end

  describe '.client_for_user_agent' do
    subject { described_class.client_for_user_agent(user_agent) }

    context 'when user agent is from a web browser' do
      let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }

      it { is_expected.to eq('web') }
    end

    context 'when user agent is from VS Code' do
      let(:user_agent) { 'vs-code-gitlab-workflow/3.11.1 VSCode/1.52.1 Node.js/12.14.1 (darwin; x64)' }

      it { is_expected.to eq('vscode') }
    end

    context 'when user agent is from JetBrains plugin' do
      let(:user_agent) { 'gitlab-jetbrains-plugin/0.0.1 intellij-idea/2021.2.4 java/11.0.13 mac-os-x/aarch64/12.1' }

      it { is_expected.to eq('jetbrains') }
    end

    context 'when user agent is from JetBrains bundled plugin' do
      let(:user_agent) do
        'IntelliJ-GitLab-Plugin PhpStorm/PS-232.6734.11 (JRE 17.0.7+7-b966.2; Linux 6.2.0-20-generic; amd64)'
      end

      it { is_expected.to eq('jetbrains_bundled') }
    end

    context 'when user agent is from Visual Studio extension' do
      let(:user_agent) { 'code-completions-language-server-experiment (gl-visual-studio-extension:1.0.0.0; arch:X64;)' }

      it { is_expected.to eq('visual_studio') }
    end

    context 'when user agent is from Neovim plugin' do
      let(:user_agent) do
        'code-completions-language-server-experiment (Neovim:0.9.0; gitlab.vim (v0.1.0); arch:amd64; os:darwin)'
      end

      it { is_expected.to eq('neovim') }
    end

    context 'when user agent is from GitLab CLI (old format)' do
      let(:user_agent) { 'GLab - GitLab CLI' }

      it { is_expected.to eq('gitlab_cli') }
    end

    context 'when user agent is from GitLab CLI (current format)' do
      let(:user_agent) { 'glab/v1.25.3-27-g7ec258fb (built 2023-02-16), darwin' }

      it { is_expected.to eq('gitlab_cli') }
    end

    context 'when user agent is nil' do
      let(:user_agent) { nil }

      it { is_expected.to be_nil }
    end
  end
end
