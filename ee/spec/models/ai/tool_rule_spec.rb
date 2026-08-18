# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRule, feature_category: :duo_agent_platform do
  let_it_be(:namespace) { create(:namespace) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:project).optional }
  end

  describe 'validations' do
    subject(:tool_rule) { build(:ai_tool_rule, namespace: namespace) }

    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:tool_name) }
    it { is_expected.to validate_uniqueness_of(:tool_name).scoped_to(:namespace_id, :project_id) }

    describe 'tool_name inclusion' do
      it 'is valid with a known tool name' do
        tool_rule.tool_name = 'create_issue'

        expect(tool_rule).to be_valid
      end

      it 'is invalid with an unknown tool name' do
        tool_rule.tool_name = 'invented_tool'

        expect(tool_rule).not_to be_valid
        expect(tool_rule.errors[:tool_name]).to include(/is not a known tool name/)
      end
    end

    describe 'validate_access_permissions_present' do
      it 'is valid when only web_access is set' do
        tool_rule.web_access = :ask
        tool_rule.local_access = nil

        expect(tool_rule).to be_valid
      end

      it 'is valid when only local_access is set' do
        tool_rule.web_access = nil
        tool_rule.local_access = :deny

        expect(tool_rule).to be_valid
      end

      it 'is valid when both are set' do
        tool_rule.web_access = :allow
        tool_rule.local_access = :ask

        expect(tool_rule).to be_valid
      end

      it 'is valid when only background_access is set' do
        tool_rule.web_access = nil
        tool_rule.local_access = nil
        tool_rule.background_access = :deny

        expect(tool_rule).to be_valid
      end

      it 'is invalid when all three are nil' do
        tool_rule.web_access = nil
        tool_rule.local_access = nil
        tool_rule.background_access = nil

        expect(tool_rule).not_to be_valid
        expect(tool_rule.errors[:base]).to include(/must have at least one/)
      end
    end

    describe 'enum values' do
      it 'accepts allow, ask, deny for web_access' do
        %i[allow ask deny].each do |value|
          tool_rule.web_access = value

          expect(tool_rule).to be_valid
        end
      end

      it 'accepts allow, ask, deny for local_access' do
        %i[allow ask deny].each do |value|
          tool_rule.local_access = value

          expect(tool_rule).to be_valid
        end
      end

      it 'accepts allow and deny for background_access' do
        %i[allow deny].each do |value|
          tool_rule.background_access = value

          expect(tool_rule).to be_valid
        end
      end

      it 'raises when background_access is set to ask (no approver on a background flow)' do
        expect { tool_rule.background_access = :ask }.to raise_error(ArgumentError)
      end

      it 'raises on invalid enum value' do
        expect { tool_rule.web_access = :invalid }.to raise_error(ArgumentError)
      end
    end

    describe 'tool_arguments json schema' do
      it 'is valid when tool_arguments is nil' do
        tool_rule.tool_arguments = nil

        expect(tool_rule).to be_valid
      end

      it 'is valid with properly formatted tool_arguments' do
        tool_rule.tool_arguments = { 'param1' => 'value1', 'param2' => 42 }

        expect(tool_rule).to be_valid
      end

      it 'is invalid when tool_arguments is not an object' do
        tool_rule.tool_arguments = [1, 2, 3]

        expect(tool_rule).not_to be_valid
        expect(tool_rule.errors[:tool_arguments]).to be_present
      end

      it 'is invalid when tool_arguments exceeds size limit' do
        tool_rule.tool_arguments = { 'key' => 'a' * 64.kilobytes }

        expect(tool_rule).not_to be_valid
        expect(tool_rule.errors[:tool_arguments]).to be_present
      end
    end

    describe 'tool_source' do
      it 'is set from the registry before validation' do
        tool_rule.tool_name = 'create_issue'
        tool_rule.tool_source = nil
        tool_rule.valid?

        expect(tool_rule.tool_source).to eq('gitlab')
      end

      it 'does not override an existing tool_source' do
        tool_rule.tool_source = 'mcp'
        tool_rule.valid?

        expect(tool_rule.tool_source).to eq('mcp')
      end

      it 'does not set tool_source when tool_name is blank' do
        tool_rule.tool_name = nil
        tool_rule.tool_source = nil
        tool_rule.valid?

        expect(tool_rule.tool_source).to be_nil
      end
    end

    describe 'project_belongs_to_namespace validation' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:other_project) { create(:project, namespace: other_namespace) }

      it 'is valid when project belongs to namespace' do
        rule = build(:ai_tool_rule, namespace: namespace, project: project)

        expect(rule).to be_valid
      end

      it 'is invalid when project does not belong to namespace' do
        rule = build(:ai_tool_rule, namespace: namespace, project: other_project)

        expect(rule).not_to be_valid
        expect(rule.errors[:project]).to include('must belong to the namespace')
      end
    end

    describe 'project_rule_not_looser_than_namespace validation' do
      let_it_be(:project) { create(:project, namespace: namespace) }

      context 'when no namespace rule exists' do
        it 'is valid with any access value' do
          rule = build(:ai_tool_rule, namespace: namespace, project: project, web_access: :allow)

          expect(rule).to be_valid
        end
      end

      context 'when a namespace rule exists' do
        let_it_be(:namespace_rule) do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
        end

        it 'is valid when project rule is equally restrictive' do
          rule = build(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue',
            web_access: :ask)

          expect(rule).to be_valid
        end

        it 'is valid when project rule is stricter' do
          rule = build(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue',
            web_access: :deny)

          expect(rule).to be_valid
        end

        it 'is invalid when project rule is looser than namespace rule', :aggregate_failures do
          rule = build(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue',
            web_access: :allow)

          expect(rule).not_to be_valid
          expect(rule.errors[:web_access]).to include('cannot be less restrictive than the namespace rule (ask)')
        end

        it 'validates local_access independently', :aggregate_failures do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'read_file', local_access: :deny)

          rule = build(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'read_file',
            local_access: :allow)

          expect(rule).not_to be_valid
          expect(rule.errors[:local_access]).to include('cannot be less restrictive than the namespace rule (deny)')
        end

        it 'validates background_access independently', :aggregate_failures do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'run_command', background_access: :deny)

          rule = build(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'run_command',
            background_access: :allow)

          expect(rule).not_to be_valid
          expect(rule.errors[:background_access])
            .to include('cannot be less restrictive than the namespace rule (deny)')
        end
      end
    end
  end

  describe '#access_for' do
    subject(:tool_rule) do
      build(:ai_tool_rule, namespace: namespace, web_access: :allow, local_access: :deny, background_access: :deny)
    end

    it 'returns web_access for web surface' do
      expect(tool_rule.access_for('web')).to eq('allow')
    end

    it 'returns web_access for ambient surface' do
      expect(tool_rule.access_for('ambient')).to eq('allow')
    end

    it 'returns local_access for local surface' do
      expect(tool_rule.access_for('local')).to eq('deny')
    end

    it 'returns local_access for other non-background surfaces (ide, chat)' do
      expect(tool_rule.access_for('ide')).to eq('deny')
      expect(tool_rule.access_for('chat')).to eq('deny')
    end

    it 'returns background_access for background surface' do
      # web and local are both allow here, so a deny can only come from background_access
      rule = build(:ai_tool_rule, namespace: namespace, web_access: :allow, local_access: :allow,
        background_access: :deny)

      expect(rule.access_for('background')).to eq('deny')
      expect(rule.access_for(:background)).to eq('deny')
    end
  end

  describe 'scopes' do
    describe '.for_namespace' do
      let_it_be(:other_namespace) { create(:namespace) }
      let_it_be(:rule) { create(:ai_tool_rule, namespace: namespace) }
      let_it_be(:other_rule) { create(:ai_tool_rule, namespace: other_namespace, tool_name: 'read_file') }

      it 'returns rules for the given namespace' do
        expect(described_class.for_namespace(namespace.id)).to contain_exactly(rule)
      end

      it 'does not return rules for other namespaces' do
        expect(described_class.for_namespace(namespace.id)).not_to include(other_rule)
      end

      it 'returns empty when no rules exist for namespace' do
        expect(described_class.for_namespace(create(:namespace).id)).to be_empty
      end

      it 'excludes project-scoped rules' do
        project = create(:project, namespace: namespace)
        namespace_rule = create(:ai_tool_rule, namespace: namespace, tool_name: 'read_file')
        project_rule = create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'run_command')

        expect(described_class.for_namespace(namespace.id)).to include(namespace_rule)
        expect(described_class.for_namespace(namespace.id)).not_to include(project_rule)
      end
    end

    describe '.for_project' do
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:project_rule) do
        create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'read_file')
      end

      it 'returns rules for the given project' do
        expect(described_class.for_project(project.id)).to contain_exactly(project_rule)
      end

      it 'does not return namespace-only rules' do
        namespace_rule = create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue')

        expect(described_class.for_project(project.id)).not_to include(namespace_rule)
      end
    end

    describe '.for_tool_names' do
      let_it_be(:rule_create_issue) { create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue') }
      let_it_be(:rule_read_file) { create(:ai_tool_rule, namespace: namespace, tool_name: 'read_file') }
      let_it_be(:rule_run_command) { create(:ai_tool_rule, namespace: namespace, tool_name: 'run_command') }

      it 'returns rules matching the given tool names' do
        expect(described_class.for_tool_names(%w[create_issue read_file]))
          .to contain_exactly(rule_create_issue, rule_read_file)
      end

      it 'does not return rules for other tool names' do
        expect(described_class.for_tool_names(%w[create_issue read_file]))
          .not_to include(rule_run_command)
      end

      it 'returns empty when no rules match' do
        expect(described_class.for_tool_names(%w[invented_tool])).to be_empty
      end

      it 'returns all rules when all tool names match' do
        expect(described_class.for_tool_names(%w[create_issue read_file run_command]))
          .to contain_exactly(rule_create_issue, rule_read_file, rule_run_command)
      end
    end
  end
end
