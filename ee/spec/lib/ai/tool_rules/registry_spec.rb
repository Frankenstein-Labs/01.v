# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRules::Registry, feature_category: :duo_agent_platform do
  before do
    described_class.instance_variable_set(:@catalog_tool_names, nil)
    described_class.instance_variable_set(:@all_tool_names, nil)
    described_class.instance_variable_set(:@action_type_for, nil)
  end

  describe 'PRIVILEGE_GROUP_MAPPING' do
    it 'contains no duplicate tool names within a group' do
      described_class::PRIVILEGE_GROUP_MAPPING.each do |group, tools|
        expect(tools.uniq).to eq(tools), "Duplicate tool names found in #{group}"
      end
    end

    it 'contains no duplicate tool names across groups' do
      all_tools = described_class::PRIVILEGE_GROUP_MAPPING.values.flatten

      expect(all_tools.uniq).to eq(all_tools)
    end

    it 'contains only non-empty strings' do
      described_class::PRIVILEGE_GROUP_MAPPING.each do |group, tools|
        expect(tools).to all(be_a(String).and(be_present)), "Non-empty string check failed in #{group}"
      end
    end
  end

  describe '.catalog_tool_names' do
    it 'returns tool names from the catalog' do
      expect(described_class.catalog_tool_names).to include('create_issue', 'read_file', 'run_command')
    end

    it 'returns only strings' do
      expect(described_class.catalog_tool_names).to all(be_a(String))
    end
  end

  describe '.all_tool_names' do
    it 'only includes tools that are mapped in PRIVILEGE_GROUP_MAPPING' do
      expect(described_class.all_tool_names).to all(satisfy { |name|
        described_class::PRIVILEGE_GROUP_FOR.key?(name)
      })
    end

    it 'excludes catalog tools that have no privilege group mapping' do
      unmapped = described_class.catalog_tool_names - described_class::PRIVILEGE_GROUP_FOR.keys

      expect(described_class.all_tool_names).not_to include(*unmapped) if unmapped.any?
    end
  end

  describe 'PRIVILEGE_GROUP_FOR' do
    it 'maps every tool name to a privilege group' do
      expect(described_class.all_tool_names).to all(satisfy { |name|
        described_class::PRIVILEGE_GROUP_FOR[name].present?
      })
    end

    it 'maps to a key that exists in PRIVILEGE_GROUP_MAPPING' do
      expect(described_class::PRIVILEGE_GROUP_FOR.values).to all(satisfy { |group|
        described_class::PRIVILEGE_GROUP_MAPPING.key?(group)
      })
    end
  end

  describe '.action_type_for' do
    it 'maps every tool name to an action type' do
      expect(described_class.all_tool_names).to all(satisfy { |name|
        described_class.action_type_for[name].present?
      })
    end

    it 'only maps to valid action types' do
      valid_types = described_class::ACTION_TYPE_GROUPS.keys

      expect(described_class.action_type_for.values).to all(be_in(valid_types))
    end

    it 'maps read_only_gitlab tools to :read' do
      tools = described_class::PRIVILEGE_GROUP_MAPPING[:read_only_gitlab] & described_class.all_tool_names

      expect(tools).to all(satisfy { |name|
        described_class.action_type_for[name] == :read
      })
    end

    it 'maps read_only_files tools to :read' do
      tools = described_class::PRIVILEGE_GROUP_MAPPING[:read_only_files] & described_class.all_tool_names

      expect(tools).to all(satisfy { |name|
        described_class.action_type_for[name] == :read
      })
    end

    it 'maps read_write_files tools to :write' do
      tools = described_class::PRIVILEGE_GROUP_MAPPING[:read_write_files] & described_class.all_tool_names

      expect(tools).to all(satisfy { |name|
        described_class.action_type_for[name] == :write
      })
    end

    it 'maps run_commands tools to :destroy' do
      tools = described_class::PRIVILEGE_GROUP_MAPPING[:run_commands] & described_class.all_tool_names

      expect(tools).to all(satisfy { |name|
        described_class.action_type_for[name] == :destroy
      })
    end

    it 'maps use_git tools to :destroy' do
      tools = described_class::PRIVILEGE_GROUP_MAPPING[:use_git] & described_class.all_tool_names

      expect(tools).to all(satisfy { |name|
        described_class.action_type_for[name] == :destroy
      })
    end
  end

  describe 'CATEGORY_FOR_GROUP' do
    it 'has a category for every privilege group' do
      described_class::PRIVILEGE_GROUP_MAPPING.each_key do |group|
        expect(described_class::CATEGORY_FOR_GROUP).to have_key(group),
          "No category defined for privilege group #{group}"
      end
    end

    it 'contains only non-empty strings' do
      expect(described_class::CATEGORY_FOR_GROUP.values).to all(be_a(String).and(be_present))
    end
  end

  describe '.source_for' do
    it 'returns "gitlab" for a standard GitLab tool' do
      expect(described_class.source_for('create_issue')).to eq('gitlab')
    end

    it 'returns "gitlab" for a file tool' do
      expect(described_class.source_for('read_file')).to eq('gitlab')
    end

    it 'returns "gitlab" for an unknown tool name' do
      expect(described_class.source_for('unknown_tool')).to eq('gitlab')
    end
  end

  describe '.default_permission_for' do
    it 'returns "ask" with no arguments' do
      expect(described_class.default_permission_for).to eq('ask')
    end

    it 'returns "allow" for a tool in a preapproved group' do
      read_tool = described_class::PRIVILEGE_GROUP_MAPPING[:read_only_gitlab].first
      expect(described_class.default_permission_for(tool_name: read_tool)).to eq('allow')
    end

    it 'returns "ask" for a tool not in a preapproved group' do
      write_tool = described_class::PRIVILEGE_GROUP_MAPPING[:read_write_gitlab].first
      expect(described_class.default_permission_for(tool_name: write_tool)).to eq('ask')
    end

    context 'when group_name is provided directly' do
      it 'returns "allow" for the read-only GitLab group' do
        expect(described_class.default_permission_for(group_name: :read_only_gitlab)).to eq('allow')
      end

      it 'returns "ask" for the read-only files group (local filesystem, least privilege)' do
        expect(described_class.default_permission_for(group_name: :read_only_files)).to eq('ask')
      end

      it 'returns "ask" for the read-write files group (includes command execution)' do
        expect(described_class.default_permission_for(group_name: :read_write_files)).to eq('ask')
      end

      it 'returns "ask" for the run_commands (destroy) group' do
        expect(described_class.default_permission_for(group_name: :run_commands)).to eq('ask')
      end

      it 'returns "ask" for the use_git (destroy) group' do
        expect(described_class.default_permission_for(group_name: :use_git)).to eq('ask')
      end

      it 'returns "ask" for a non-preapproved group' do
        expect(described_class.default_permission_for(group_name: :read_write_gitlab)).to eq('ask')
      end
    end

    it 'gives group_name precedence when both tool_name and group_name are provided' do
      read_tool = described_class::PRIVILEGE_GROUP_MAPPING[:read_only_gitlab].first

      expect(described_class.default_permission_for(tool_name: read_tool, group_name: :read_write_gitlab)).to eq('ask')
    end

    it 'returns "ask" for an unmapped tool name' do
      expect(described_class.default_permission_for(tool_name: 'not_a_real_tool')).to eq('ask')
    end
  end

  describe 'catalog coverage' do
    it 'has every catalog tool either mapped or explicitly opted out' do
      mapped = described_class::PRIVILEGE_GROUP_FOR.keys
      opted_out = described_class::UNGOVERNED_TOOLS # see point 2
      unaccounted = described_class.catalog_tool_names - mapped - opted_out

      expect(unaccounted).to be_empty, <<~MSG
        New catalog tools detected without a privilege group:
          #{unaccounted.join("\n  ")}

        Add each tool to the appropriate group in
        ee/lib/ai/tool_rules/registry.rb (PRIVILEGE_GROUP_MAPPING),
        or to UNGOVERNED_TOOLS if it is intentionally ungovernable.
      MSG
    end
  end

  describe '.to_mcp_tool_names' do
    it 'maps known catalog names to their MCP names' do
      expect(described_class.to_mcp_tool_names(['create_issue'])).to match_array(['create_work_item'])
    end

    it 'passes unknown catalog names through unchanged' do
      expect(described_class.to_mcp_tool_names(['unknown_tool'])).to match_array(['unknown_tool'])
    end

    it 'handles a mix of known and unknown names' do
      expect(described_class.to_mcp_tool_names(%w[create_issue unknown_tool get_issue]))
        .to match_array(%w[create_work_item unknown_tool get_issue])
    end
  end
end
