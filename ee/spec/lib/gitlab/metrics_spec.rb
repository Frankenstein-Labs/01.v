# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics, feature_category: :error_budgets do
  describe '.initialize_slis!', feature_category: :error_budgets do
    # This context is replicating the specs in spec/lib/gitlab/metrics_spec.rb
    # within the EE context.

    let!(:puma_slis) do
      [
        Gitlab::Metrics::RequestsRackMiddleware,
        Gitlab::Metrics::GlobalSearchSlis,
        Gitlab::Metrics::Middleware::PathTraversalCheck
      ]
    end

    let!(:sidekiq_slis) do
      [
        Gitlab::Metrics::Lfs,
        Gitlab::Metrics::LooseForeignKeysSlis,
        Gitlab::Metrics::GlobalSearchIndexingSlis,
        Gitlab::Metrics::Llm,
        Gitlab::Metrics::SecurityScanSlis
      ]
    end

    context 'when puma runtime' do
      it "initializes only puma SLIs" do
        allow(Gitlab::Runtime).to receive_messages(puma?: true, sidekiq?: false)

        expect(Gitlab::Metrics::SliConfig.enabled_slis).to include(*puma_slis)
        expect(Gitlab::Metrics::SliConfig.enabled_slis).not_to include(*sidekiq_slis)
        expect(Gitlab::Metrics::SliConfig.enabled_slis).to all(receive(:initialize_slis!))

        described_class.initialize_slis!
      end
    end

    context 'when sidekiq runtime' do
      it "initializes only sidekiq SLIs" do
        allow(Gitlab::Runtime).to receive_messages(puma?: false, sidekiq?: true)

        expect(Gitlab::Metrics::SliConfig.enabled_slis).not_to include(*puma_slis)
        expect(Gitlab::Metrics::SliConfig.enabled_slis).to include(*sidekiq_slis)
        expect(Gitlab::Metrics::SliConfig.enabled_slis).to all(receive(:initialize_slis!))

        described_class.initialize_slis!
      end
    end
  end
end
