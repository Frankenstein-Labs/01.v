# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::CustomInstruction, feature_category: :duo_code_review do
  using RSpec::Parameterized::TableSyntax

  let(:name) { 'Test instruction' }
  let(:instructions) { 'Do something' }
  let(:include_patterns) { [] }
  let(:exclude_patterns) { [] }
  let(:location) { 'https://gitlab.com/gitlab-org/gitlab/.gitlab/duo/mr-review-instructions.yaml' }
  let(:instruction) { described_class.new(name:, instructions:, include_patterns:, exclude_patterns:, location:) }

  describe '#valid?' do
    subject(:valid) { instruction.valid? }

    where(:name, :instructions, :expected_valid) do
      nil    | nil            | false
      nil    | '  '           | false
      nil    | 'Instructions' | false
      '  '   | nil            | false
      '  '   | '  '           | false
      'Name' | nil            | false
      'Name' | 'Instructions' | true
    end

    with_them do
      context "with name = #{params[:name].inspect} and instructions = #{params[:instructions].inspect}" do
        it { is_expected.to be(expected_valid) }
      end
    end
  end

  describe '#apply_to?' do
    subject(:apply_to) { instruction.apply_to?(path) }

    context 'with no include or exclude patterns' do
      let(:include_patterns) { [] }
      let(:exclude_patterns) { [] }

      it 'applies to any path' do
        expect(instruction.apply_to?('app/models/user.rb')).to be(true)
        expect(instruction.apply_to?('lib/service.ts')).to be(true)
        expect(instruction.apply_to?('spec/models/user_spec.rb')).to be(true)
      end
    end

    context 'with include patterns only' do
      let(:include_patterns) { ['app/models/**/*'] }

      context 'when the path matches an include pattern' do
        let(:path) { 'app/models/user.rb' }

        it { is_expected.to be(true) }
      end

      context 'when the path does not match any include pattern' do
        let(:path) { 'lib/service.rb' }

        it { is_expected.to be(false) }
      end

      context 'with multiple include patterns' do
        let(:include_patterns) { ['app/models/**/*', 'lib/**/*'] }

        it 'applies when the path matches any include pattern' do
          expect(instruction.apply_to?('app/models/user.rb')).to be(true)
          expect(instruction.apply_to?('lib/service.rb')).to be(true)
          expect(instruction.apply_to?('spec/models/user_spec.rb')).to be(false)
        end
      end
    end

    context 'with exclude patterns only' do
      let(:exclude_patterns) { ['spec/**/*'] }

      context 'when the path matches an exclude pattern' do
        let(:path) { 'spec/models/user_spec.rb' }

        it { is_expected.to be(false) }
      end

      context 'when the path does not match any exclude pattern' do
        let(:path) { 'app/models/user.rb' }

        it { is_expected.to be(true) }
      end

      context 'with multiple exclude patterns' do
        let(:exclude_patterns) { ['spec/**/*', 'vendor/**/*'] }

        it 'does not apply when the path matches any exclude pattern' do
          expect(instruction.apply_to?('spec/models/user_spec.rb')).to be(false)
          expect(instruction.apply_to?('vendor/gems/foo.rb')).to be(false)
        end
      end
    end

    context 'with both include and exclude patterns' do
      let(:include_patterns) { ['app/**/*'] }
      let(:exclude_patterns) { ['app/models/**/*'] }

      context 'when the path matches include but also matches exclude' do
        let(:path) { 'app/models/user.rb' }

        it 'does not apply (exclude wins)' do
          is_expected.to be(false)
        end
      end

      context 'when the path matches include and does not match exclude' do
        let(:path) { 'app/controllers/users_controller.rb' }

        it { is_expected.to be(true) }
      end

      context 'when the path does not match include at all' do
        let(:path) { 'lib/service.rb' }

        it { is_expected.to be(false) }
      end
    end

    context 'with glob patterns' do
      context 'with a double-star glob' do
        let(:include_patterns) { ['**/*.rb'] }
        let(:path) { 'app/models/concerns/auditable.rb' }

        it { is_expected.to be(true) }
      end

      context 'with a single-star glob' do
        let(:include_patterns) { ['app/models/*.rb'] }

        it 'matches files directly in the directory but not subdirectories' do
          expect(instruction.apply_to?('app/models/user.rb')).to be(true)
          expect(instruction.apply_to?('app/models/concerns/auditable.rb')).to be(false)
        end
      end

      context 'with an exact path pattern' do
        let(:include_patterns) { ['app/models/user.rb'] }

        it 'only matches the exact path' do
          expect(instruction.apply_to?('app/models/user.rb')).to be(true)
          expect(instruction.apply_to?('app/models/post.rb')).to be(false)
        end
      end

      # File::FNM_PATHNAME makes * not match /, so patterns must use ** to cross directories.
      # Without the flag, *.rb would match app/models/user.rb because * would consume the slashes.
      context 'when include pattern uses single star without a path prefix' do
        let(:include_patterns) { ['*.rb'] }

        it 'does not match nested paths because * cannot cross directory separators' do
          expect(instruction.apply_to?('user.rb')).to be(true)
          expect(instruction.apply_to?('app/user.rb')).to be(false)
          expect(instruction.apply_to?('app/models/user.rb')).to be(false)
        end
      end

      context 'when exclude pattern uses single star without a path prefix' do
        let(:exclude_patterns) { ['*.rb'] }

        it 'does not exclude nested paths because * cannot cross directory separators' do
          expect(instruction.apply_to?('user.rb')).to be(false)
          expect(instruction.apply_to?('app/user.rb')).to be(true)
          expect(instruction.apply_to?('app/models/user.rb')).to be(true)
        end
      end

      context 'when pattern uses ** to explicitly cross directory separators' do
        let(:include_patterns) { ['**/*.rb'] }

        it 'matches nested paths at any depth' do
          expect(instruction.apply_to?('user.rb')).to be(true)
          expect(instruction.apply_to?('app/user.rb')).to be(true)
          expect(instruction.apply_to?('app/models/user.rb')).to be(true)
          expect(instruction.apply_to?('app/models/concerns/auditable.rb')).to be(true)
        end
      end

      # File::FNM_EXTGLOB enables extglob syntax from extended shell glob patterns.
      context 'with extglob patterns (File::FNM_EXTGLOB)' do
        context 'with brace alternation' do
          let(:include_patterns) { ['**/*.{rb,ts}'] }

          it 'matches files with any of the listed extensions' do
            expect(instruction.apply_to?('app/models/user.rb')).to be(true)
            expect(instruction.apply_to?('app/components/user.ts')).to be(true)
            expect(instruction.apply_to?('app/components/user.js')).to be(false)
          end
        end

        context 'with brace alternation for multiple directories' do
          let(:include_patterns) { ['{app,lib}/**/*.rb'] }

          it 'matches files under any of the listed directories' do
            expect(instruction.apply_to?('app/models/user.rb')).to be(true)
            expect(instruction.apply_to?('lib/service.rb')).to be(true)
            expect(instruction.apply_to?('spec/models/user_spec.rb')).to be(false)
          end
        end

        context 'with brace alternation in exclude patterns' do
          let(:exclude_patterns) { ['**/*.{rb,py}'] }

          it 'excludes files matching any of the listed extensions' do
            expect(instruction.apply_to?('app/models/user.rb')).to be(false)
            expect(instruction.apply_to?('scripts/deploy.py')).to be(false)
            expect(instruction.apply_to?('app/components/user.ts')).to be(true)
          end
        end
      end
    end
  end

  describe '#to_h' do
    let(:include_patterns) { ['include/*.rb'] }
    let(:exclude_patterns) { ['exclude/*.rb'] }

    it 'returns a hash with all attributes' do
      expect(instruction.to_h).to eq(
        {
          name: 'Test instruction',
          instructions: 'Do something',
          include_patterns: ['include/*.rb'],
          exclude_patterns: ['exclude/*.rb'],
          location: 'https://gitlab.com/gitlab-org/gitlab/.gitlab/duo/mr-review-instructions.yaml'
        }.with_indifferent_access
      )
    end
  end

  describe '#[]' do
    it 'returns the value for the given key' do
      expect(instruction[:name]).to eq('Test instruction')
      expect(instruction[:instructions]).to eq('Do something')
    end

    context 'when the key does not exist' do
      it 'returns nil' do
        expect(instruction[:nonexistent]).to be_nil
      end
    end
  end
end
