# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceToken, feature_category: :workspaces do
  include ::TokenAuthenticatableMatchers

  let_it_be(:workspace) { create(:workspace) }

  subject(:workspace_token) { create(:workspace_token, workspace: workspace) }

  context "when created from factory" do
    subject(:created_workspace_token) { create(:workspace_token) }

    it "has correct associations from factory" do
      expect(created_workspace_token.workspace).to be_a(RemoteDevelopment::Workspace)
    end
  end

  describe "#ensure_token" do
    subject(:built_workspace_token) { build(:workspace_token, workspace: workspace, token_encrypted: nil) }

    it "ensures token is generated before validation" do
      expect(built_workspace_token.token).to be_nil

      built_workspace_token.valid?

      expect(built_workspace_token.token).to be_present
      expect(built_workspace_token.token.length).to be >= 50
    end
  end

  describe "#token" do
    let(:token_owner_record) { workspace_token }
    let(:expected_token_prefix) { described_class::TOKEN_PREFIX }

    subject(:token) { token_owner_record.token }

    shared_examples 'has a prefix' do
      it 'starts with prefix' do
        workspace_token = build(:workspace_token, workspace: workspace, token_encrypted: nil)
        workspace_token.save!

        expect(workspace_token.token).to start_with expected_prefix
      end
    end

    it_behaves_like 'has a prefix' do
      let(:expected_prefix) { described_class::TOKEN_PREFIX }
    end

    context 'with instance prefix configured' do
      let(:instance_prefix) { 'instanceprefix' }

      before do
        stub_application_setting(instance_token_prefix: instance_prefix)
      end

      it_behaves_like 'has a prefix' do
        let(:expected_prefix) { "#{instance_prefix}-#{described_class::TOKEN_PREFIX}" }
      end

      context 'with feature flag custom_prefix_for_all_token_types disabled' do
        before do
          stub_feature_flags(custom_prefix_for_all_token_types: false)
        end

        it_behaves_like 'has a prefix' do
          let(:expected_prefix) { described_class::TOKEN_PREFIX }
        end
      end
    end

    include_context "with token authenticatable routable token context"

    describe "encrypted routable token" do
      let(:expected_routing_payload) do
        "c:1\n" \
          "o:#{workspace.project.organization.id.to_s(36)}\n" \
          "u:#{workspace.user.id.to_s(36)}"
      end

      it_behaves_like "an encrypted routable token" do
        let(:expected_token) { token }
        let(:expected_random_bytes) { random_bytes }
        let(:expected_encrypted_token) { token_owner_record.token_encrypted }
      end
    end
  end

  describe "callbacks" do
    describe "#set_project_id" do
      it "sets the project_id before creation" do
        workspace_token.save!

        expect(workspace_token.project_id).to eq(workspace.project_id)
      end
    end

    describe "#ensure_token" do
      it "ensures a token" do
        expect(workspace_token.token_encrypted).not_to be_empty
        expect(workspace_token.token).not_to be_nil
        expect(workspace_token.token.length).to be >= 50
      end
    end
  end

  describe "associations" do
    context "for belongs_to" do
      it { is_expected.to belong_to(:workspace).class_name("RemoteDevelopment::Workspace").required }
    end
  end

  describe "validations" do
    describe "workspace_id uniqueness" do
      subject(:unsaved_workspace_token) { build(:workspace_token, workspace: workspace, token_encrypted: nil) }

      before do
        create(:workspace_token, workspace: workspace)
      end

      it "validates uniqueness of workspace_id" do
        expect(unsaved_workspace_token).not_to be_valid
        expect(unsaved_workspace_token.errors[:workspace_id]).to include("has already been taken")
      end
    end
  end
end
