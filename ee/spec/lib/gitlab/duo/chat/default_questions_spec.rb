# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Duo::Chat::DefaultQuestions, feature_category: :duo_chat do
  describe "#execute" do
    subject { described_class.new(user, url: url, resource: resource).execute }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let(:url) { nil }

    context "with allowed resource" do
      context "with issue resource" do
        let(:issue) { build_stubbed(:issue, project: project) }
        let(:resource) { ::Ai::AiResource::Issue.new(user, issue) }

        before do
          allow(user).to receive(:allowed_to_use?)
            .with(:ask_issue, root_namespace: project.root_ancestor)
            .and_return(true)
        end

        it { is_expected.to include("What key decisions were made in this issue?") }
      end

      context "with merge request resource" do
        let(:merge_request) { build_stubbed(:merge_request, source_project: project) }
        let(:resource) { ::Ai::AiResource::MergeRequest.new(user, merge_request) }

        before do
          allow(user).to receive(:allowed_to_use?)
            .with(:ask_merge_request, root_namespace: project.root_ancestor)
            .and_return(true)
        end

        it { is_expected.to include("What changed in this diff?") }
      end

      context "with ci job resource" do
        let(:ci_build) { build_stubbed(:ci_build, project: project) }
        let(:resource) { ::Ai::AiResource::Ci::Build.new(user, ci_build) }

        before do
          allow(user).to receive(:allowed_to_use?)
            .with(:ask_build, root_namespace: project.root_ancestor)
            .and_return(true)
        end

        it { is_expected.to include("What was each stage's final status?") }
      end

      context "with epic resource" do
        let(:group) { create(:group) }
        let(:epic) { build_stubbed(:epic, group: group) }
        let(:resource) { ::Ai::AiResource::Epic.new(user, epic) }

        before do
          allow(user).to receive(:allowed_to_use?)
            .with(:ask_epic, root_namespace: group.root_ancestor)
            .and_return(true)
        end

        it { is_expected.to include("What key features are planned?") }
      end

      context "with commit resource" do
        let(:commit) { build_stubbed(:commit, project: project) }
        let(:resource) { ::Ai::AiResource::Commit.new(user, commit) }

        before do
          allow(user).to receive(:allowed_to_use?)
            .with(:ask_commit, root_namespace: project.root_ancestor)
            .and_return(true)
        end

        it { is_expected.to include("How can I test these changes?") }
      end
    end

    context "without allowed resource" do
      let(:issue) { build_stubbed(:issue, project: project) }
      let(:resource) { ::Ai::AiResource::Issue.new(user, issue) }

      before do
        allow(user).to receive(:allowed_to_use?)
          .with(:ask_issue, root_namespace: project.root_ancestor)
          .and_return(false)
      end

      it "returns default questions" do
        is_expected.to include("How do I estimate story points?")
      end
    end

    context "with code url" do
      let(:url) { Gitlab::Routing.url_helpers.project_blob_url(project, 'readme.md') }
      let(:resource) { nil }

      it { is_expected.to include("What does this code do?") }
    end

    context "with project wiki url" do
      let(:url) { Gitlab::Routing.url_helpers.project_wiki_url(project, 'home') }
      let(:resource) { nil }

      it "returns the wiki related questions" do
        is_expected.to include("Where can I see page version history?")
      end
    end

    context "with group wiki url" do
      let(:url) { Gitlab::Routing.url_helpers.group_wiki_url(group, 'home') }
      let(:resource) { nil }

      it "returns the wiki related questions" do
        is_expected.to include("Where can I see page version history?")
      end
    end

    context "with random url" do
      let(:url) { Gitlab::Routing.url_helpers.project_url(project) }
      let(:resource) { nil }

      it "returns default questions" do
        is_expected.to include("How do I estimate story points?")
      end
    end
  end
end
