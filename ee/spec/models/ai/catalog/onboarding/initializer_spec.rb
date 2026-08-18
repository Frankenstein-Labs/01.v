# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Onboarding::Initializer, feature_category: :workflow_catalog do
  let(:project_context) { described_class.find('init_project_context') }
  let(:improve_ci) { described_class.find('improve_ci') }
  let(:codeowners) { described_class.find('init_codeowners') }
  let(:chat_rules) { described_class.find('init_chat_rules') }

  describe '.all' do
    it 'defines the expected initializers' do
      expect(described_class.all.map(&:event_type))
        .to contain_exactly('init_project_context', 'improve_ci', 'init_execution_env',
          'init_mr_review_instructions', 'init_codeowners', 'init_chat_rules')
    end

    it 'exposes display metadata for each initializer', :aggregate_failures do
      initializers = described_class.all

      initializers.each do |initializer|
        expect(initializer.display_name).to be_present
        expect(initializer.description).to be_present
        expect(initializer.target_file).to be_present
      end
    end
  end

  describe '.find' do
    it 'finds an initializer by event_type' do
      expect(described_class.find('improve_ci').target_file).to eq('.gitlab-ci.yml')
    end

    it 'returns nil for an unknown event_type' do
      expect(described_class.find('nope')).to be_nil
    end
  end

  describe 'applicability' do
    context 'when the target files are absent' do
      let_it_be(:project) { create(:project, :custom_repo, files: { 'README.md' => 'hello' }) }

      it 'enables create-a-file initializers and skips improve_ci as prerequisite_missing',
        :aggregate_failures do
        expect(project_context.applicable_for?(project)).to be(true)
        expect(project_context.skip_reason(project)).to be_nil

        expect(improve_ci.applicable_for?(project)).to be(false)
        expect(improve_ci.skip_reason(project)).to eq(:prerequisite_missing)
      end
    end

    context 'when the target files already exist' do
      let_it_be(:project) do
        create(:project, :custom_repo, files: { 'AGENTS.md' => 'x', '.gitlab-ci.yml' => "test:\n  script: true" })
      end

      it 'skips the create-a-file initializer as already_present and enables improve_ci',
        :aggregate_failures do
        expect(project_context.applicable_for?(project)).to be(false)
        expect(project_context.skip_reason(project)).to eq(:already_present)

        expect(improve_ci.applicable_for?(project)).to be(true)
      end
    end

    context 'when .gitlab/duo/chat-rules.md is absent' do
      let_it_be(:project) { create(:project, :custom_repo, files: { 'README.md' => 'hello' }) }

      it 'enables the chat-rules initializer', :aggregate_failures do
        expect(chat_rules.applicable_for?(project)).to be(true)
        expect(chat_rules.skip_reason(project)).to be_nil
      end
    end

    context 'when .gitlab/duo/chat-rules.md already exists on the default branch' do
      let_it_be(:project) do
        create(:project, :custom_repo, files: { '.gitlab/duo/chat-rules.md' => '- be brief' })
      end

      it 'skips the chat-rules initializer as already_present', :aggregate_failures do
        expect(chat_rules.applicable_for?(project)).to be(false)
        expect(chat_rules.skip_reason(project)).to eq(:already_present)
      end
    end

    context 'when a target file exists but is empty (zero-byte)' do
      let_it_be(:project) { create(:project, :custom_repo, files: { '.gitlab-ci.yml' => '' }) }

      it 'treats a zero-byte file as present (uses blob_at, not the old .present? check)' do
        expect(improve_ci.applicable_for?(project)).to be(true)
      end
    end

    context 'when the initializer checks CODEOWNERS surface coverage' do
      let_it_be(:reviewer) { create(:user) }

      def full_coverage(owner)
        "AGENTS.md #{owner}\n.gitlab/duo/ #{owner}\nskills/ #{owner}\n"
      end

      it 'is applicable when the active CODEOWNERS covers none of the agent surfaces' do
        project = create(:project, :custom_repo, files: { 'CODEOWNERS' => "*.rb @#{reviewer.username}\n" })
        project.add_developer(reviewer)

        expect(codeowners.applicable_for?(project)).to be(true)
      end

      it 'is applicable when the active CODEOWNERS covers only some agent surfaces' do
        project = create(:project, :custom_repo, files: { 'CODEOWNERS' => ".gitlab/duo/ @#{reviewer.username}\n" })
        project.add_developer(reviewer)

        expect(codeowners.applicable_for?(project)).to be(true)
      end

      it 'is already_present when all surfaces are owned by a real project member', :aggregate_failures do
        project = create(:project, :custom_repo, files: { 'CODEOWNERS' => full_coverage("@#{reviewer.username}") })
        project.add_developer(reviewer)

        expect(codeowners.applicable_for?(project)).to be(false)
        expect(codeowners.skip_reason(project)).to eq(:already_present)
      end

      it 'is applicable when the owner does not resolve to a real user or group' do
        project = create(:project, :custom_repo, files: { 'CODEOWNERS' => full_coverage('@nobody') })

        expect(codeowners.applicable_for?(project)).to be(true)
      end

      it 'ignores coverage in a lower-priority CODEOWNERS file' do
        project = create(:project, :custom_repo, files: {
          'CODEOWNERS' => "*.rb @#{reviewer.username}\n",
          'docs/CODEOWNERS' => full_coverage("@#{reviewer.username}")
        })
        project.add_developer(reviewer)

        expect(codeowners.applicable_for?(project)).to be(true)
      end
    end
  end
end
