# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/bundle_validator'

RSpec.describe Ai::DuoWorkflows::CommandValidators::BundleValidator, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  subject(:validator) { described_class.new }

  describe '#safe_for_pattern_matching?' do
    context 'with allowed subcommands (read/inspect only)' do
      %w[list show check info outdated version platform doctor viz].each do |subcommand|
        it "allows #{subcommand}" do
          expect(validator.safe_for_pattern_matching?(program: 'bundle', tokens: [subcommand])).to be true
        end
      end
    end

    context 'when commands should be allowed' do
      where(:description, :tokens) do
        [
          ['list', %w[list]],
          ['show with gem name', %w[show rails]],
          ['check', %w[check]],
          ['info with gem name', %w[info rspec]],
          ['outdated', %w[outdated]],
          ['--verbose global option', %w[--verbose list]],
          ['version', %w[version]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'bundle', tokens: tokens)).to be true
        end
      end
    end

    context 'when commands should be rejected' do
      where(:description, :tokens) do
        [
          # Execute/persist subcommands require exact-match
          ['exec (runs arbitrary commands)', %w[exec rails server]],
          ['install (state change)', %w[install]],
          ['update (state change)', %w[update]],
          ['add (state change)', %w[add rspec]],
          ['remove (state change)', %w[remove rspec]],
          ['console (interactive execution)', %w[console]],
          ['open (opens gem, potential code exec)', %w[open rails]],
          ['config (persistent mutation)', %w[config set path /evil]],
          ['init (creates files)', %w[init]],
          ['unknown subcommand', %w[exploit something]],

          # Dangerous flags on allowed subcommands
          ['--gemfile (loads arbitrary Gemfile)', %w[list --gemfile /evil/Gemfile]],

          # Structure validation
          ['empty tokens', []],
          ['disallowed global option', %w[--evil-flag list]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'bundle', tokens: tokens)).to be false
        end
      end
    end
  end
end
