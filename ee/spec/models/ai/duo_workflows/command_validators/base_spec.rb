# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'

RSpec.describe Ai::DuoWorkflows::CommandValidators::Base, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  describe '#safe_for_pattern_matching? (subcommand-based mode)' do
    let(:validator_class) do
      # Use const_set to define constants on the anonymous class itself,
      # not on Object (which would leak to all classes).
      klass = Class.new(described_class)
      klass.const_set(:ALLOWED_SUBCOMMANDS, Set.new(%w[install test build]).freeze)
      klass.const_set(:ALLOWED_GLOBAL_OPTIONS, Set.new(%w[--verbose --json]).freeze)
      klass.const_set(:DANGEROUS_FLAGS, Set.new(%w[--exec --unsafe]).freeze)
      klass.const_set(:DANGEROUS_FLAG_PREFIXES, %w[--exec= --unsafe=].freeze)
      klass.const_set(:DANGEROUS_COMPOUND_COMMANDS, { 'test' => Set.new(%w[run]).freeze }.freeze)
      klass
    end

    subject(:validator) { validator_class.new }

    context 'with allowed commands' do
      where(:description, :tokens) do
        [
          ['simple subcommand', %w[install]],
          ['subcommand with positional args',   %w[install react lodash]],
          ['subcommand with safe flags',        %w[build --minify]],
          ['allowed global option',             %w[--verbose install]],
          ['multiple allowed global options',   %w[--verbose --json test]],
          ['safe compound (same subcommand)',   %w[test unit]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: tokens)).to be true
        end
      end
    end

    context 'with rejected commands' do
      where(:description, :tokens) do
        [
          ['unknown subcommand', %w[exec something]],
          ['no subcommand (empty)',             []],
          ['no subcommand (flags only)',        %w[--version]],
          ['disallowed global option',          %w[--dangerous-flag install]],
          ['dangerous flag in subcommand args', %w[install --exec evil]],
          ['dangerous flag prefix',             %w[install --exec=evil]],
          ['dangerous compound command',        %w[test run evil-script]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: tokens)).to be false
        end
      end
    end
  end

  describe '#safe_for_pattern_matching? (simple mode)' do
    let(:validator_class) do
      klass = Class.new(described_class)
      klass.const_set(:DANGEROUS_FLAGS, Set.new(%w[-f --file -C]).freeze)
      klass.const_set(:DANGEROUS_FLAG_PREFIXES, %w[-f= --file= -C=].freeze)
      klass
    end

    subject(:validator) { validator_class.new }

    context 'with allowed commands' do
      where(:description, :tokens) do
        [
          ['positional args only',     %w[build test]],
          ['safe flags',               %w[-j4 all]],
          ['empty tokens',             []],
          ['single target',            %w[clean]]
        ]
      end

      with_them do
        it "allows #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: tokens)).to be true
        end
      end
    end

    context 'with rejected commands' do
      where(:description, :tokens) do
        [
          ['dangerous flag',           %w[-f evil-file build]],
          ['dangerous flag long form', %w[--file evil-file build]],
          ['dangerous flag prefix',    %w[-f=evil-file build]],
          ['dangerous flag mid-args',  %w[build -C /evil/dir]]
        ]
      end

      with_them do
        it "rejects #{params[:description]}" do
          expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: tokens)).to be false
        end
      end
    end
  end

  describe '#safe_for_pattern_matching? (bare base with no constants)' do
    subject(:validator) { described_class.new }

    it 'uses simple mode and allows any tokens' do
      expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: %w[anything goes])).to be true
    end

    it 'allows empty tokens' do
      expect(validator.safe_for_pattern_matching?(program: 'tool', tokens: [])).to be true
    end
  end
end
