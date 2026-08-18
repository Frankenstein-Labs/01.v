# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::NamespacePolicy, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  describe 'for a group subject' do
    let_it_be(:root_group, freeze: false) { create(:group) }
    let_it_be(:subgroup, freeze: false) { create(:group, parent: root_group) }

    let_it_be(:guest) { create(:user, guest_of: root_group) }
    let_it_be(:developer) { create(:user, developer_of: root_group) }
    let_it_be(:non_member) { create(:user) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(root_group, :ai_catalog).and_return(true)
      root_group.namespace_settings.duo_features_enabled = true
    end

    describe ':read_ai_catalog_mcp_server' do
      where(:user, :mcp_servers_available, :mcp_enabled, :result) do
        ref(:guest)      | true  | true  | true
        ref(:guest)      | true  | false | false
        ref(:guest)      | false | true  | false
        ref(:developer)  | true  | true  | true
        ref(:non_member) | true  | true  | false
      end

      with_them do
        subject(:policy_instance) { GroupPolicy.new(user, root_group) }

        before do
          allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(mcp_servers_available)
          root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: mcp_enabled })
        end

        it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to eq(result) }
      end

      context 'when subject is a subgroup' do
        subject(:policy_instance) { GroupPolicy.new(developer, subgroup) }

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(subgroup, :ai_catalog).and_return(true)
          subgroup.namespace_settings.duo_features_enabled = true
          allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(developer).and_return(true)
        end

        context 'when root_ancestor has duo_workflow_mcp_enabled' do
          before do
            root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: true })
          end

          it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to be(true) }
        end

        context 'when root_ancestor does not have duo_workflow_mcp_enabled' do
          before do
            root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: false })
          end

          it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to be(false) }
        end
      end
    end
  end

  describe 'for a project subject' do
    let_it_be(:root_group, freeze: false) { create(:group) }
    let_it_be(:project) { create(:project, group: root_group) }

    let_it_be(:guest) { create(:user, guest_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }
    let_it_be(:non_member) { create(:user) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
      project.update!(duo_features_enabled: true)
    end

    describe ':read_ai_catalog_mcp_server' do
      where(:user, :mcp_servers_available, :mcp_enabled, :result) do
        ref(:guest)      | true  | true  | true
        ref(:guest)      | true  | false | false
        ref(:guest)      | false | true  | false
        ref(:developer)  | true  | true  | true
        ref(:non_member) | true  | true  | false
      end

      with_them do
        subject(:policy_instance) { ProjectPolicy.new(user, project) }

        before do
          allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(mcp_servers_available)
          root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: mcp_enabled })
        end

        it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to eq(result) }
      end

      context 'when project is in a subgroup' do
        let_it_be(:subgroup, freeze: false) { create(:group, parent: root_group) }
        let_it_be(:subproject) { create(:project, group: subgroup) }
        let_it_be(:sub_developer) { create(:user, developer_of: subproject) }

        subject(:policy_instance) { ProjectPolicy.new(sub_developer, subproject) }

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(subproject, :ai_catalog).and_return(true)
          subproject.update!(duo_features_enabled: true)
          allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(sub_developer).and_return(true)
        end

        context 'when root_ancestor has duo_workflow_mcp_enabled' do
          before do
            root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: true })
          end

          it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to be(true) }
        end

        context 'when root_ancestor does not have duo_workflow_mcp_enabled' do
          before do
            root_group.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: false })
          end

          it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to be(false) }
        end
      end
    end
  end
end
