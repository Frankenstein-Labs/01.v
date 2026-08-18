# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/npm_validator'

RSpec.describe Ai::DuoWorkflows::CommandValidators::NpmValidator, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  subject(:validator) { described_class.new }

  describe '#safe_for_pattern_matching?' do
    context 'with allowed subcommands (read/inspect only)' do
      %w[list outdated audit view info search ls fund explain prefix root].each do |subcommand|
        it "allows #{subcommand}" do
          expect(validator.safe_for_pattern_matching?(program: 'npm', tokens: [subcommand])).to be true
        end
      end
    end

    context 'when commands should be allowed' do
      where(:description, :tokens) do
        [
          ['list',                               %w[list]],
          ['outdated',                           %w[outdated]],
          ['audit',                              %w[audit]],
          ['view with package name',             %w[view react]],
          ['--verbose global option',            %w[--verbose list]],
          ['--json global option',               %w[--json list]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'npm', tokens: tokens)).to be true
        end
      end
    end

    context 'when commands should be rejected' do
      where(:description, :tokens) do
        [
          # Execute/persist subcommands require exact-match
          ['install (state change)',                 %w[install react]],
          ['run (executes scripts)',                 %w[run build]],
          ['exec (arbitrary package execution)',     %w[exec cowsay hello]],
          ['ci (state change)',                      %w[ci]],
          ['build (executes scripts)',               %w[build]],
          ['test (executes scripts)',                %w[test]],
          ['start (executes scripts)',               %w[start]],
          ['config set (persistent mutation)', %w[config set script-shell evil]],
          ['get (alias for config get, can leak auth)', %w[get registry]],
          ['publish (publishes to registry)',        %w[publish]],
          ['init (creates files)',                   %w[init]],
          ['unknown subcommand',                     %w[exploit something]],

          # Dangerous flags on allowed subcommands
          ['--prefix on list', %w[list --prefix /evil/path]],

          # Structure validation
          ['empty tokens', []],
          ['flags only (no subcommand)', %w[--version]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'npm', tokens: tokens)).to be false
        end
      end
    end
  end
end
