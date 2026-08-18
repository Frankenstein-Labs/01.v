# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/docker_validator'

RSpec.describe Ai::DuoWorkflows::CommandValidators::DockerValidator, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  subject(:validator) { described_class.new }

  describe '#safe_for_pattern_matching?' do
    context 'with allowed subcommands (read/inspect only)' do
      %w[ps images logs inspect stats top port diff events history version info].each do |subcommand|
        it "allows #{subcommand}" do
          expect(validator.safe_for_pattern_matching?(program: 'docker', tokens: [subcommand])).to be true
        end
      end
    end

    context 'when commands should be allowed' do
      where(:description, :tokens) do
        [
          ['ps list all', %w[ps -a]],
          ['images with filter', %w[images --filter dangling=true]],
          ['logs with follow', %w[logs -f container_id]],
          ['inspect container', %w[inspect mycontainer]],
          ['stats', %w[stats --no-stream]],
          ['version', %w[version]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'docker', tokens: tokens)).to be true
        end
      end
    end

    context 'when commands should be rejected' do
      where(:description, :tokens) do
        [
          # Execute/persist subcommands require exact-match
          ['run (executes containers)', %w[run nginx]],
          ['build (builds images)', %w[build .]],
          ['exec (executes in container)', %w[exec -it mycontainer bash]],
          ['compose (orchestrates services)', %w[compose up -d]],
          ['pull (downloads images)', %w[pull nginx]],
          ['push (publishes images)', %w[push myimage]],
          ['create (creates containers)', %w[create nginx]],
          ['rm (removes containers)', %w[rm mycontainer]],
          ['load (loads image from file)', %w[load -i image.tar]],
          ['import (imports filesystem)', %w[import file.tar]],
          ['unknown subcommand', %w[exploit something]],

          # Disallowed global options
          ['-H flag (remote Docker daemon)', %w[-H tcp://evil:2375 ps]],

          # Structure validation
          ['empty tokens', []],
          ['flags only (no subcommand)', %w[--version]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'docker', tokens: tokens)).to be false
        end
      end
    end
  end
end
