# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::PoststartCommandsHelper, feature_category: :workspaces do
  let(:described_class) do
    Class.new do
      extend RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::PoststartCommandsHelper
    end
  end

  describe '.extract_poststart_commands' do
    let(:devfile_commands) do
      [
        { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
        { id: 'cmd2', exec: { component: 'container2', commandLine: 'echo test2' } },
        { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } }
      ]
    end

    context 'when postStart events are present' do
      let(:devfile_events) { { postStart: %w[cmd1 cmd3] } }

      it 'returns matching commands' do
        result = described_class.extract_poststart_commands(
          devfile_commands: devfile_commands,
          devfile_events: devfile_events
        )

        expect(result).to eq([
          { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
          { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } }
        ])
      end
    end

    context 'when postStart events are empty' do
      let(:devfile_events) { { postStart: [] } }

      it 'returns empty array' do
        result = described_class.extract_poststart_commands(
          devfile_commands: devfile_commands,
          devfile_events: devfile_events
        )

        expect(result).to eq([])
      end
    end

    context 'when command ID does not exist' do
      let(:devfile_events) { { postStart: %w[cmd1 nonexistent cmd3] } }

      it 'filters out non-existent commands' do
        result = described_class.extract_poststart_commands(
          devfile_commands: devfile_commands,
          devfile_events: devfile_events
        )

        expect(result).to eq([
          { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
          { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } }
        ])
      end
    end
  end

  describe '.extract_main_component_name' do
    context 'when main component exists' do
      let(:processed_devfile) do
        {
          components: [
            { name: 'secondary-container', attributes: {} },
            { name: 'main-container', attributes: { 'gl/inject-editor': true } },
            { name: 'another-container', attributes: {} }
          ]
        }
      end

      it 'returns the main component name' do
        result = described_class.extract_main_component_name(processed_devfile: processed_devfile)
        expect(result).to eq('main-container')
      end
    end
  end

  describe '.get_container_names_with_poststart_commands' do
    let(:poststart_commands) do
      [
        { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
        { id: 'cmd2', exec: { component: 'container2', commandLine: 'echo test2' } },
        { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } },
        { id: 'cmd4', exec: { component: 'container3', commandLine: 'echo test4' } }
      ]
    end

    it 'returns unique container names' do
      result = described_class.get_container_names_with_poststart_commands(
        poststart_commands: poststart_commands
      )

      expect(result).to match_array(%w[container1 container2 container3])
    end
  end

  describe '.internal_blocking_command_label_present?' do
    context 'when internal blocking commands are present' do
      let(:poststart_commands) do
        [
          { id: 'user-cmd', exec: { component: 'container1', commandLine: 'echo user' } },
          { id: 'internal-cmd',
            exec: { component: 'container1', commandLine: 'echo internal', label: 'gl-internal-blocking' } }
        ]
      end

      it 'returns true' do
        result = described_class.internal_blocking_command_label_present?(
          poststart_commands: poststart_commands
        )

        expect(result).to be true
      end
    end

    context 'when no internal blocking commands are present' do
      let(:poststart_commands) do
        [
          { id: 'user-cmd1', exec: { component: 'container1', commandLine: 'echo user1' } },
          { id: 'user-cmd2', exec: { component: 'container2', commandLine: 'echo user2' } }
        ]
      end

      it 'returns false' do
        result = described_class.internal_blocking_command_label_present?(
          poststart_commands: poststart_commands
        )

        expect(result).to be false
      end
    end
  end

  describe '.partition_poststart_commands' do
    let(:poststart_commands) do
      [
        { id: 'user-cmd1', exec: { component: 'container1', commandLine: 'echo user1' } },
        { id: 'internal-cmd1',
          exec: { component: 'container1', commandLine: 'echo internal1', label: 'gl-internal-blocking' } },
        { id: 'user-cmd2', exec: { component: 'container2', commandLine: 'echo user2' } },
        { id: 'internal-cmd2',
          exec: { component: 'container1', commandLine: 'echo internal2', label: 'gl-internal-blocking' } }
      ]
    end

    it 'partitions commands correctly' do
      internal_commands, non_blocking_commands = described_class.partition_poststart_commands(
        poststart_commands: poststart_commands
      )

      expect(internal_commands).to eq([
        { id: 'internal-cmd1',
          exec: { component: 'container1', commandLine: 'echo internal1', label: 'gl-internal-blocking' } },
        { id: 'internal-cmd2',
          exec: { component: 'container1', commandLine: 'echo internal2', label: 'gl-internal-blocking' } }
      ])

      expect(non_blocking_commands).to eq([
        { id: 'user-cmd1', exec: { component: 'container1', commandLine: 'echo user1' } },
        { id: 'user-cmd2', exec: { component: 'container2', commandLine: 'echo user2' } }
      ])
    end
  end

  describe '.group_commands_by_component' do
    let(:non_blocking_commands) do
      [
        { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
        { id: 'cmd2', exec: { component: 'container2', commandLine: 'echo test2' } },
        { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } },
        { id: 'cmd4', exec: { component: 'container3', commandLine: 'echo test4' } }
      ]
    end

    it 'groups commands by component' do
      result = described_class.group_commands_by_component(
        non_blocking_commands: non_blocking_commands
      )

      expect(result).to eq({
        'container1' => [
          { id: 'cmd1', exec: { component: 'container1', commandLine: 'echo test1' } },
          { id: 'cmd3', exec: { component: 'container1', commandLine: 'echo test3' } }
        ],
        'container2' => [
          { id: 'cmd2', exec: { component: 'container2', commandLine: 'echo test2' } }
        ],
        'container3' => [
          { id: 'cmd4', exec: { component: 'container3', commandLine: 'echo test4' } }
        ]
      })
    end
  end
end
