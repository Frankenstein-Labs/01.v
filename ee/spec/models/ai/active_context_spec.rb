# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  describe '.paused?' do
    subject(:paused) { described_class.paused? }

    context 'when indexing is disabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'when indexing is enabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
      end

      context 'when neither global nor feature-level pause is set' do
        before do
          stub_application_setting(elasticsearch_pause_indexing: false, active_context_pause_indexing: false)
        end

        it { is_expected.to be false }
      end

      context 'when global elasticsearch_pause_indexing is true' do
        before do
          stub_application_setting(elasticsearch_pause_indexing: true, active_context_pause_indexing: false)
        end

        it { is_expected.to be true }
      end

      context 'when feature-level active_context_pause_indexing is true' do
        before do
          stub_application_setting(elasticsearch_pause_indexing: false, active_context_pause_indexing: true)
        end

        it { is_expected.to be true }
      end

      context 'when both global and feature-level are true' do
        before do
          stub_application_setting(elasticsearch_pause_indexing: true, active_context_pause_indexing: true)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe '.semantic_search_available?' do
    where(:ai_features_available, :duo_features_enabled, :expected_result) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      it 'checks the instance license and settings' do
        allow(License).to receive(:ai_features_available?).and_return(ai_features_available)
        allow(::Gitlab::CurrentSettings).to receive(:duo_features_enabled?).and_return(duo_features_enabled)

        expect(described_class.semantic_search_available?).to eq(expected_result)
      end
    end
  end

  describe '.gitlab_selects_embedding_model?' do
    subject(:gitlab_selects_embedding_model) { described_class.gitlab_selects_embedding_model? }

    context 'for semantic search on SaaS' do
      include_context 'for semantic search on SaaS'

      it { is_expected.to be(true) }
    end

    context 'for semantic search on Dedicated' do
      include_context 'for semantic search on Dedicated'

      it { is_expected.to be(true) }
    end

    context 'for semantic search on Self-Managed without self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed without self-hosted AIGW'

      it { is_expected.to be(true) }
    end

    context 'for semantic search on Self-Managed with self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed with self-hosted AIGW'

      it { is_expected.to be(false) }
    end
  end

  describe '.user_selects_embedding_model?' do
    subject(:user_selects_embedding_model) { described_class.user_selects_embedding_model? }

    context 'for semantic search on SaaS' do
      include_context 'for semantic search on SaaS'

      it { is_expected.to be(false) }
    end

    context 'for semantic search on Dedicated' do
      include_context 'for semantic search on Dedicated'

      it { is_expected.to be(false) }
    end

    context 'for semantic search on Self-Managed without self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed without self-hosted AIGW'

      it { is_expected.to be(false) }
    end

    context 'for semantic search on Self-Managed with self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed with self-hosted AIGW'

      it { is_expected.to be(true) }
    end
  end
end
