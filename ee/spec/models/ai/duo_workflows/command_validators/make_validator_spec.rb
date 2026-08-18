# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/make_validator'

RSpec.describe Ai::DuoWorkflows::CommandValidators::MakeValidator, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  subject(:validator) { described_class.new }

  describe '#safe_for_pattern_matching?' do
    context 'when commands should be allowed (simple tool, no subcommand validation)' do
      where(:description, :tokens) do
        [
          ['single target',          %w[build]],
          ['multiple targets',       %w[clean build test]],
          ['target with -j flag',    %w[-j4 all]],
          ['empty tokens (bare make)', []],
          ['install target',         %w[install]],
          ['target with VAR=val',    %w[build DEBUG=1]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'make', tokens: tokens)).to be true
        end
      end
    end

    context 'when commands should be rejected' do
      where(:description, :tokens) do
        [
          # Dangerous flags that redirect Makefile or directory
          ['-f (alternative Makefile)',           %w[-f /evil/Makefile build]],
          ['--file (alternative Makefile)',       %w[--file /evil/Makefile build]],
          ['--makefile (alternative Makefile)',   %w[--makefile /evil/Makefile build]],
          ['-f= form', %w[-f=/evil/Makefile build]],
          ['-C (change directory)',               %w[-C /evil/dir build]],
          ['--directory (change directory)',      %w[--directory /evil/dir build]],
          ['-I (include directory)',              %w[-I /evil/include build]],
          ['--include-dir (include directory)',   %w[--include-dir /evil/include build]],
          ['-e (environment overrides)',          %w[-e build]],
          ['-e= form (environment overrides)',   %w[-e=SHELL=/bin/evil build]],
          ['--environment-overrides',            %w[--environment-overrides build]],
          ['dangerous flag in middle of args',   %w[build -C /evil test]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'make', tokens: tokens)).to be false
        end
      end
    end
  end
end
