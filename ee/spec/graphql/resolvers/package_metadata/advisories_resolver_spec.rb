# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::PackageMetadata::AdvisoriesResolver, feature_category: :software_composition_analysis do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:current_user) { create(:user, namespace: namespace) }
  let_it_be(:advisory_1) do
    create(:pm_advisory, identifiers: [
      { type: 'CVE', name: 'CVE-2026-1234', value: 'CVE-2026-1234', url: 'https://example.com/cve' }
    ])
  end

  let_it_be(:advisory_2) do
    create(:pm_advisory, identifiers: [
      { type: 'CVE', name: 'CVE-2026-5678', value: 'CVE-2026-5678', url: 'https://example.com/cve2' }
    ])
  end

  let_it_be(:advisory_3) do
    create(:pm_advisory, identifiers: [
      { type: 'GHSA', name: 'GHSA-2026-1234', value: 'GHSA-2026-1234', url: 'https://example.com/ghsa' }
    ])
  end

  before do
    stub_feature_flags(pm_advisory_graphql: true)
    stub_licensed_features(dependency_scanning: true)
  end

  describe '#resolve' do
    context 'when searching by identifiers' do
      subject(:resolve_advisories) do
        sync(resolve(described_class, obj: nil, args: { identifiers: identifiers }, ctx: { current_user: current_user },
          arg_style: :internal))
      end

      context 'with a single valid identifier' do
        let(:identifiers) { ['CVE-2026-1234'] }

        it 'returns matching advisory' do
          expect(resolve_advisories.items).to contain_exactly(advisory_1)
        end
      end

      context 'with multiple valid identifiers' do
        let(:identifiers) { %w[CVE-2026-1234 CVE-2026-5678] }

        it 'returns all matching advisories' do
          expect(resolve_advisories.items).to contain_exactly(advisory_1, advisory_2)
        end
      end

      context 'with mixed valid and invalid identifiers' do
        let(:identifiers) { %w[CVE-2026-1234 CVE-9999-9999] }

        it 'returns only matching advisories' do
          expect(resolve_advisories.items).to contain_exactly(advisory_1)
        end
      end

      context 'with no matching identifiers' do
        let(:identifiers) { %w[CVE-9999-9999 CVE-8888-8888] }

        it 'returns empty result' do
          expect(resolve_advisories.items).to be_empty
        end
      end

      context 'with no identifiers given' do
        let(:identifiers) { %w[] }

        it 'returns empty result' do
          expect(resolve_advisories.items).to be_empty
        end
      end

      context 'with empty identifiers given' do
        let(:identifiers) { %w['', ' '] }

        it 'returns empty result' do
          expect(resolve_advisories.items).to be_empty
        end
      end

      context 'with partly empty identifiers given' do
        let(:identifiers) { ['CVE-2026-1234', ''] }

        it 'returns empty result' do
          expect(resolve_advisories.items).to contain_exactly(advisory_1)
        end
      end

      context 'with GHSA identifier' do
        let(:identifiers) { ['GHSA-2026-1234'] }

        it 'returns matching advisory' do
          expect(resolve_advisories.items).to contain_exactly(advisory_3)
        end
      end
    end

    context 'when filtering by created_after' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: identifiers, created_after: created_after },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      let(:identifiers) { %w[CVE-2026-1234 CVE-2026-5678 GHSA-2026-1234] }
      let(:created_after) { 1.hour.ago }

      it 'returns advisories created after the specified time' do
        # All advisories are created after 1 hour ago, so all should be returned
        expect(resolve_advisories.items.length).to eq(3)
      end
    end

    context 'when filtering by updated_after' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: identifiers, updated_after: updated_after },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      let(:identifiers) { %w[CVE-2026-1234 CVE-2026-5678 GHSA-2026-1234] }
      let(:updated_after) { 1.hour.ago }

      it 'returns advisories updated after the specified time' do
        # All advisories are updated after 1 hour ago, so all should be returned
        expect(resolve_advisories.items.length).to eq(3)
      end
    end

    context 'when combining multiple filters' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: identifiers, created_after: created_after },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      let(:identifiers) { %w[CVE-2026-1234 CVE-2026-5678] }
      let(:created_after) { 1.hour.ago }

      it 'applies all filters' do
        # Both advisories match the identifiers and created_after filter
        expect(resolve_advisories.items.length).to eq(2)
      end
    end

    context 'when user is not authenticated' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: ['CVE-2026-1234'] },
          ctx: { current_user: nil },
          arg_style: :internal
        ))
      end

      it 'returns nil' do
        expect(resolve_advisories).to be_nil
      end
    end

    context 'when feature flag is disabled' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: ['CVE-2026-1234'] },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      before do
        stub_feature_flags(pm_advisory_graphql: false)
      end

      it 'returns nil' do
        expect(resolve_advisories).to be_nil
      end
    end

    context 'when dependency_scanning license is not available' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: ['CVE-2026-1234'] },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      before do
        stub_licensed_features(dependency_scanning: false)
      end

      it 'returns nil' do
        expect(resolve_advisories).to be_nil
      end
    end

    context 'when too many identifiers are provided' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: identifiers },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      context 'with more than MAX_IDENTIFIERS identifiers' do
        let(:identifiers) { Array.new(described_class::MAX_IDENTIFIERS + 1) { |i| "CVE-2026-#{i}" } }

        it 'raises an argument error' do
          expect(resolve_advisories).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        end

        it 'returns an error with the correct message' do
          expect(resolve_advisories.message).to match(/Too many identifiers/)
        end
      end

      context 'with exactly MAX_IDENTIFIERS identifiers' do
        let(:identifiers) { Array.new(described_class::MAX_IDENTIFIERS) { |i| "CVE-2026-#{i}" } }

        it 'does not raise an error' do
          expect(resolve_advisories).not_to be_a(Gitlab::Graphql::Errors::ArgumentError)
        end
      end
    end

    context 'when rate limit is exceeded' do
      subject(:resolve_advisories) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { identifiers: ['CVE-2026-1234'] },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      before do
        allow(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:package_metadata, scope: [current_user]).and_return(true)
        )
      end

      it 'raises a resource not available error' do
        expect(resolve_advisories).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end

      it 'returns an error with the correct message' do
        expect(resolve_advisories.message).to match(/too many times/)
      end
    end
  end
end
