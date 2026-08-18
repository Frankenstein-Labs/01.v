# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SlashCommandsService, feature_category: :duo_chat do
  let(:user) { create(:user) }

  let(:base_commands) do
    [
      { description: "New chat conversation.", name: "/new", should_submit: false },
      { description: "Learn what Duo Chat can do.", name: "/help", should_submit: true }
    ]
  end

  before do
    stub_feature_flags(work_item_legacy_url: true)
  end

  shared_examples 'returns only base commands' do
    it 'returns only base commands' do
      expect(available_commands).to eq(base_commands)
    end
  end

  describe '#available_commands' do
    subject(:available_commands) { described_class.new(user, url).available_commands }

    context 'with unknown context' do
      let(:url) { 'https://gitlab.com/some/unknown/path' }
      let(:namespace) { create(:namespace) }

      before do
        allow_next_instance_of(::Gitlab::Llm::Utils::RouteHelper) do |helper|
          allow(helper).to receive(:namespace).and_return(namespace)
        end
      end

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).with(namespace).and_return(true)
        end

        it_behaves_like 'returns only base commands'
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).with(namespace).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end

      context 'when user is not authorized' do
        let(:user) { nil }

        it_behaves_like 'returns only base commands'
      end
    end

    context 'when no namespace is found' do
      let(:url) { 'https://gitlab.com/' }

      before do
        allow_next_instance_of(::Gitlab::Llm::Utils::RouteHelper) do |helper|
          allow(helper).to receive(:namespace).and_return(nil)
        end
      end

      it_behaves_like 'returns only base commands'
    end

    context 'with issue context' do
      let_it_be(:project) { create(:project) }
      let(:issue) { create(:issue, project: project) }

      context 'on individual issue page' do
        let(:url) { ::Gitlab::UrlBuilder.instance.issue_url(issue) }

        context 'when user has Duo Enterprise access' do
          before do
            allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
          end

          it 'returns base commands and issue-specific commands' do
            expected_commands = base_commands + described_class.commands[:issue]
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when user does not have Duo Enterprise access' do
          before do
            allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
          end

          it_behaves_like 'returns only base commands'
        end
      end

      context 'on issues index page' do
        let(:url) { Gitlab::Routing.url_helpers.project_issues_url(project) }

        context 'when user has Duo Enterprise access' do
          before do
            allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
          end

          it 'returns base commands without /summarize_comments' do
            expected_commands = base_commands
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when user does not have Duo Enterprise access' do
          before do
            allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
          end

          it_behaves_like 'returns only base commands'
        end
      end
    end

    context 'with job context' do
      let_it_be(:project) { create(:project) }
      let(:job) { create(:ci_build, :failed, project: project) }
      let(:url) { Gitlab::Routing.url_helpers.project_job_url(project, job) }

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
        end

        context 'when job is failed' do
          it 'returns base commands and job-specific commands' do
            expected_commands = base_commands + described_class.commands[:job]
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when job is not failed' do
          let(:job) { create(:ci_build, project: project) }

          it_behaves_like 'returns only base commands'
        end
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end
    end

    context 'with vulnerability context' do
      let_it_be(:project) { create(:project) }
      let(:vulnerability) { create(:vulnerability, :detected, :sast, project: project) }
      let(:url) { Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, vulnerability) }

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
        end

        context 'when vulnerability is SAST' do
          it 'returns base commands and vulnerability-specific commands' do
            expected_commands = base_commands + described_class.commands[:vulnerability]
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when vulnerability is not SAST' do
          let(:vulnerability) { create(:vulnerability, :detected, :container_scanning, project: project) }

          it_behaves_like 'returns only base commands'
        end
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end
    end

    context 'with invalid URL' do
      let(:url) { 'invalid_url' }

      it_behaves_like 'returns only base commands'
    end

    context 'with nil URL' do
      let(:url) { nil }

      it_behaves_like 'returns only base commands'
    end
  end

  describe '#on_issues_index_page?' do
    let_it_be(:project) { create(:project) }
    let(:issue) { create(:issue, project: project) }
    let(:service) { described_class.new(user, url) }

    subject { service.send(:on_issues_index_page?) }

    context 'when on issues index page' do
      let(:url) { Gitlab::Routing.url_helpers.project_issues_url(project) }

      it { is_expected.to be true }
    end

    context 'when on individual issue page' do
      let(:url) { ::Gitlab::UrlBuilder.instance.issue_url(issue) }

      it { is_expected.to be false }
    end

    context 'when on different controller' do
      let(:url) { 'https://gitlab.com/some/other/path' }

      before do
        allow_next_instance_of(::Gitlab::Llm::Utils::RouteHelper) do |helper|
          allow(helper).to receive_messages(
            controller: 'projects/merge_requests',
            action: 'index'
          )
        end
      end

      it { is_expected.to be false }
    end

    context 'when controller is nil' do
      let(:url) { 'invalid_url' }

      it { is_expected.to be false }
    end
  end
end
