# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::PackageMetadata::AdvisoryResolver, feature_category: :software_composition_analysis do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:current_user) { create(:user, namespace: namespace) }
  let_it_be(:advisory) do
    create(:pm_advisory, identifiers: [
      { type: 'CVE', name: 'CVE-2026-1234', value: 'CVE-2026-1234', url: 'https://example.com/cve' },
      { type: 'GHSA', name: 'GHSA-2026-1234', value: 'GHSA-2026-1234', url: 'https://example.com/ghsa' }
    ])
  end

  let(:advisory_gid) { advisory.to_global_id }

  before do
    stub_feature_flags(pm_advisory_graphql: true)
    stub_licensed_features(dependency_scanning: true)
  end

  describe '#resolve' do
    context 'when querying by id' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: { id: advisory_gid }, ctx: { current_user: current_user },
          arg_style: :internal))
      end

      it 'returns the advisory' do
        expect(resolve_advisory).to eq(advisory)
      end

      context 'when advisory does not exist' do
        let(:advisory_gid) { "gid://gitlab/PackageMetadata::Advisory/#{non_existing_record_id}" }

        it 'returns nil' do
          expect(resolve_advisory).to be_nil
        end
      end
    end

    context 'when querying by identifier' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: { identifier: identifier }, ctx: { current_user: current_user },
          arg_style: :internal))
      end

      context 'with a valid CVE identifier' do
        let(:identifier) { 'CVE-2026-1234' }

        it 'returns the advisory' do
          expect(resolve_advisory).to eq(advisory)
        end
      end

      context 'with a valid GHSA identifier' do
        let(:identifier) { 'GHSA-2026-1234' }

        it 'returns the advisory' do
          expect(resolve_advisory).to eq(advisory)
        end
      end

      context 'with a non-existent identifier' do
        let(:identifier) { 'CVE-9999-9999' }

        it 'returns nil' do
          expect(resolve_advisory).to be_nil
        end
      end
    end

    context 'when no filter is provided' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: {}, ctx: { current_user: current_user }, arg_style: :internal))
      end

      it 'raises an argmument error' do
        expect(resolve_advisory).to be_a(Gitlab::Graphql::Errors::ArgumentError)
      end

      it 'returns an error with the correct message' do
        expect(resolve_advisory.message).to eq('At least one filter must be provided')
      end
    end

    context 'when user is not authenticated' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: { id: advisory_gid }, ctx: { current_user: nil },
          arg_style: :internal))
      end

      it 'returns nil' do
        expect(resolve_advisory).to be_nil
      end
    end

    context 'when feature flag is disabled' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: { id: advisory_gid }, ctx: { current_user: current_user },
          arg_style: :internal))
      end

      before do
        stub_feature_flags(pm_advisory_graphql: false)
      end

      it 'returns nil' do
        expect(resolve_advisory).to be_nil
      end
    end

    context 'when dependency_scanning license is not available' do
      subject(:resolve_advisory) do
        sync(resolve(
          described_class,
          obj: nil,
          args: { id: advisory_gid },
          ctx: { current_user: current_user },
          arg_style: :internal
        ))
      end

      before do
        stub_licensed_features(dependency_scanning: false)
      end

      it 'returns nil' do
        expect(resolve_advisory).to be_nil
      end
    end

    context 'when rate limit is exceeded' do
      subject(:resolve_advisory) do
        sync(resolve(described_class, obj: nil, args: { id: advisory_gid }, ctx: { current_user: current_user },
          arg_style: :internal))
      end

      before do
        allow(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:package_metadata, scope: [current_user]).and_return(true)
        )
      end

      it 'raises a resource not available error' do
        expect(resolve_advisory).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end

      it 'returns an error with the correct message' do
        expect(resolve_advisory.message).to match(/too many times/)
      end
    end
  end
end
