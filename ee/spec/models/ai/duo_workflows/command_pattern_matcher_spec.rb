# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../app/models/ai/duo_workflows/command_pattern_matcher'

RSpec.describe Ai::DuoWorkflows::CommandPatternMatcher, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  describe '.match?' do
    context 'with literal patterns' do
      where(:pattern, :command, :expected) do
        [
          ['git status',                'git status',                true],
          ['git log',                   'git status',                false],
          ['git checkout main',         'git checkout main',         true],
          ['git checkout main',         'git checkout feature',      false],
          ['git',                       'git',                       true],
          ['git',                       'git status',                false],
          ['git status',                'git',                       false]
        ]
      end

      with_them do
        specify { expect(described_class.match?(pattern, command)).to eq(expected) }
      end
    end

    context 'with single wildcard (*)' do
      where(:description, :pattern, :command, :expected) do
        [
          # Basic non-flag token matching
          ['matches single non-flag token',           'git checkout *',    'git checkout main', true],
          ['matches branch with slashes',             'git checkout *',    'git checkout feature/branch',  true],
          ['matches branch with dots',                'git checkout *',    'git checkout v1.2.3',          true],

          # Flag rejection -- the core security property
          ['rejects flag token',                      'git checkout *',    'git checkout --force',         false],
          ['rejects short flag token',                'git checkout *',    'git checkout -b',              false],
          ['rejects flag with value',                 'git fetch *',       'git fetch --upload-pack=evil', false],

          # Single-token constraint
          ['rejects multiple tokens',                 'git checkout *',    'git checkout main extra',      false],
          ['multiple wildcards match multiple tokens', 'git checkout * *', 'git checkout -b new',          false],
          ['multiple wildcards both non-flag',        'git checkout * *',  'git checkout main origin',     true],

          # Wildcard in different positions
          ['wildcard as subcommand',                  'git *',             'git status',                   true],
          ['wildcard as subcommand rejects flag',     'git *',             'git --version',                false],
          ['wildcard as subcommand single token only', 'git *',            'git checkout main',            false],
          ['two wildcards for subcommand + arg',      'git * *',           'git checkout main',            true],
          ['two wildcards reject flag in second pos', 'git * *',           'git checkout --force',         false],

          # Literal flags in patterns are fine -- only wildcards are constrained
          ['literal flag in pattern matches',         'git commit -m *',   'git commit -m fix-bug',        true],
          ['literal flag in pattern no match',        'git commit -m *',   'git commit -a fix-bug',        false],
          ['literal --force in pattern',              'git push --force *', 'git push --force origin',     true]
        ]
      end

      with_them do
        it params[:description].to_s do
          expect(described_class.match?(pattern, command)).to eq(expected)
        end
      end
    end

    context 'with double wildcard (**)' do
      where(:description, :pattern, :command, :expected) do
        [
          # Zero or more tokens of any kind
          ['matches zero tokens',                     'git status **',     'git status',                    true],
          ['matches single non-flag',                 'git log **',        'git log main',                  true],
          ['matches single flag',                     'git log **',        'git log --oneline',             true],
          ['matches multiple flags',                  'git log **',        'git log --oneline --graph',     true],
          ['matches mixed flags and args',            'git log **',        'git log --oneline main',        true],
          ['matches everything after prefix',         'git **',            'git checkout -b new-branch',    true],
          ['matches flags in middle',                 'git **',            'git -c evil fetch',             true],

          # ** followed by more pattern tokens
          ['** then literal',                         'git ** main',       'git checkout main',             true],
          ['** then literal with flags between',      'git ** main',       'git --no-pager log main',       true],
          ['** then literal no match',                'git ** main',       'git checkout feature',          false],

          # Multiple ** segments
          ['two ** segments',                         'git ** -- **',      'git checkout -- -weird-file',   true]
        ]
      end

      with_them do
        it params[:description].to_s do
          expect(described_class.match?(pattern, command)).to eq(expected)
        end
      end
    end

    context 'with end-of-options separator (--)' do
      where(:description, :pattern, :command, :expected) do
        [
          # After --, * matches flag-shaped tokens (they are positional args)
          ['* matches flag-shaped token after --',    'git checkout -- *', 'git checkout -- -weird-name',   true],
          ['* matches normal token after --',         'git checkout -- *', 'git checkout -- file.txt',      true],
          ['literal -- must be present in command',   'git checkout -- *', 'git checkout file.txt',         false],
          ['-- in command not in pattern',            'git checkout *',    'git checkout -- file.txt',      false],
          ['multiple tokens after --',                'git rm -- * *',     'git rm -- -f file.txt',         true]
        ]
      end

      with_them do
        it params[:description].to_s do
          expect(described_class.match?(pattern, command)).to eq(expected)
        end
      end
    end

    context 'with embedded globs' do
      where(:description, :pattern, :command, :expected) do
        [
          ['matches branch prefix',                   'git checkout feature-*', 'git checkout feature-branch', true],
          ['no match different prefix',               'git checkout feature-*', 'git checkout hotfix-branch',  false],
          ['rejects flag-shaped target',              'git checkout feature-*', 'git checkout -feature',       false],
          ['question mark glob',                      'git checkout v?.0',      'git checkout v1.0',           true],
          ['bracket glob',                            'git checkout [abc]*',    'git checkout alpha',          true],
          ['flag-shaped pattern with glob matches flag', 'git log --format=*', 'git log --format=oneline', true]
        ]
      end

      with_them do
        it params[:description].to_s do
          expect(described_class.match?(pattern, command)).to eq(expected)
        end
      end
    end

    context 'with edge cases' do
      it 'returns false for empty pattern and non-empty command' do
        expect(described_class.match?('', 'git status')).to be false
      end

      it 'returns false for non-empty pattern and empty command' do
        expect(described_class.match?('git status', '')).to be false
      end

      it 'returns true for empty pattern and empty command' do
        expect(described_class.match?('', '')).to be true
      end

      it 'returns false for unbalanced quotes in pattern' do
        expect(described_class.match?('"git status', 'git status')).to be false
      end

      it 'returns false for unbalanced quotes in command' do
        expect(described_class.match?('git status', '"git status')).to be false
      end

      it 'handles quoted arguments correctly' do
        expect(described_class.match?('git commit -m *', 'git commit -m "fix bug"')).to be true
      end

      it 'handles ** as only pattern token matching any command' do
        expect(described_class.match?('**', 'git checkout -b feature')).to be true
      end

      it 'handles ** as only pattern token matching empty command' do
        expect(described_class.match?('**', '')).to be true
      end
    end

    context 'with security-critical scenarios' do
      where(:description, :pattern, :command, :expected) do
        [
          # Argument injection via flags -- the primary attack vector
          ['git -c injection blocked by *',              'git *',
            'git -c core.sshCommand=evil fetch',         false],
          ['upload-pack injection blocked by *',         'git fetch *',
            'git fetch --upload-pack=evil',              false],
          ['receive-pack injection blocked by *',        'git push *',
            'git push --receive-pack=evil',              false],
          ['exec injection blocked by *',                'git pull *',
            'git pull --exec=evil',                      false],
          ['template injection blocked by *',            'git init *',
            'git init --template=/evil',                 false],
          ['config injection blocked by *',              'git clone *',
            'git clone --config core.sshCommand=evil',   false],

          # Safe commands still match
          ['safe checkout matches',                      'git checkout *',
            'git checkout feature-branch',               true],
          ['safe commit matches',                        'git commit -m *',
            'git commit -m fix-bug',                     true],
          ['safe push matches',                          'git push * *',
            'git push origin main',                      true],

          # ** explicitly allows flags (opt-in)
          ['** allows flags (explicit opt-in)', 'git **',
            'git -c core.sshCommand=evil fetch', true],

          # Mixed pattern with ** and literals
          ['** with literal suffix still constrains', 'git fetch ** origin',
            'git fetch --all origin', true]
        ]
      end

      with_them do
        it params[:description].to_s do
          expect(described_class.match?(pattern, command)).to eq(expected)
        end
      end
    end
  end
end
