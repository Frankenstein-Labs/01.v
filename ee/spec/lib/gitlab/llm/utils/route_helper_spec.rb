# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Llm::Utils::RouteHelper, feature_category: :duo_chat do
  let(:helper) { described_class.new(url) }
  let_it_be(:issue) { create(:issue) }

  let(:issue_url) do
    Gitlab::Routing.url_helpers.namespace_project_issue_url(
      namespace_id: issue.project.namespace,
      project_id: issue.project,
      id: issue.iid
    )
  end

  shared_context "with unknown path" do
    let(:url) { "https://gitlab.com/some/unknown/path" }

    before do
      allow(Rails.application.routes).to receive(:recognize_path).and_return({ some: "path" })
    end
  end

  describe "#exists?" do
    subject { helper.exists? }

    context "when route exists" do
      include_context "with unknown path"

      it { is_expected.to be_truthy }
    end

    context "when url is invalid" do
      let(:url) { "invalid_url" }

      before do
        allow(Rails.application.routes).to receive(:recognize_path)
          .and_raise(ActionController::RoutingError.new("Err"))
      end

      it { is_expected.to be_falsey }
    end

    context 'when route is nil' do
      let(:url) { nil }

      it { is_expected.to be_falsey }
    end
  end

  describe "#project" do
    subject { helper.project }

    context "when project is found" do
      let(:url) { issue_url }

      it { is_expected.to eq(issue.project) }
    end

    context "when project is not found" do
      include_context "with unknown path"

      it { is_expected.to be_nil }
    end
  end

  describe "#namespace" do
    subject { helper.namespace }

    context "when namespace is found" do
      let(:url) { issue_url }

      it { is_expected.to eq(issue.project.namespace) }
    end

    context "when namespace is not found" do
      include_context "with unknown path"

      it { is_expected.to be_nil }
    end
  end

  describe "#controller" do
    subject { helper.controller }

    context "when controller is found" do
      let(:url) { 'https://gitlab.com/some/controller/path' }
      let(:expected_controller) { 'known/controller' }

      before do
        allow(Rails.application.routes).to receive(:recognize_path).and_return({ controller: expected_controller })
      end

      it { is_expected.to eq(expected_controller) }
    end

    context "when controller is not found" do
      include_context "with unknown path"

      it { is_expected.to be_nil }
    end
  end

  describe "#id" do
    subject { helper.id }

    context "when route exists" do
      let(:url) { issue_url }

      it { is_expected.to eq(issue.iid) }
    end

    context "when url is invalid" do
      include_context "with unknown path"

      it { is_expected.to be_nil }
    end
  end

  describe "#action" do
    subject { helper.action }

    context "when action is found" do
      let(:url) { 'https://gitlab.com/some/controller/path' }
      let(:expected_action) { 'show' }

      before do
        allow(Rails.application.routes).to receive(:recognize_path).and_return({ action: expected_action })
      end

      it { is_expected.to eq(expected_action) }
    end

    context "when action is not found" do
      include_context "with unknown path"

      it { is_expected.to be_nil }
    end
  end
end
