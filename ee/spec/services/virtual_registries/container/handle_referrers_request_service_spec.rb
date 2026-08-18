# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::HandleReferrersRequestService, :aggregate_failures, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let_it_be(:registry) do
    create(:virtual_registries_container_registry, group: group, upstreams: [upstream])
  end

  let(:digest) { "sha256:#{'a' * 64}" }
  let(:path) { "alpine/referrers/#{digest}" }
  let(:artifact_type) { nil }
  let(:service) do
    described_class.new(registry: registry, current_user: user, params: { path: path, artifact_type: artifact_type })
  end

  let(:upstream_url) { upstream.url_for(path) }

  describe '#execute' do
    subject(:execute) { service.execute }

    before do
      allow(upstream).to receive(:headers).and_return({})
    end

    context 'when upstream returns 200 with referrers list' do
      let(:referrers_body) do
        {
          schemaVersion: 2,
          mediaType: 'application/vnd.oci.image.index.v1+json',
          manifests: [{ mediaType: 'application/vnd.oci.image.manifest.v1+json', digest: digest, size: 1234 }]
        }.to_json
      end

      before do
        stub_request(:get, upstream_url)
          .to_return(
            status: 200,
            body: referrers_body,
            headers: { 'Content-Type' => 'application/vnd.oci.image.index.v1+json' }
          )
      end

      it 'returns success with the upstream body' do
        is_expected.to be_success
        expect(execute.payload[:raw_body]).to eq(referrers_body)
        expect(execute.payload[:filters_applied]).to be_nil
      end
    end

    context 'when upstream returns 404' do
      before do
        stub_request(:get, upstream_url)
          .to_return(status: 404, body: '{}')
      end

      it 'returns success with the empty OCI image index' do
        is_expected.to be_success
        parsed = Gitlab::Json.safe_parse(execute.payload[:raw_body])
        expect(parsed['schemaVersion']).to eq(2)
        expect(parsed['manifests']).to be_empty
      end
    end

    context 'when artifact_type param is present' do
      let(:artifact_type) { 'application/vnd.example.test' }

      before do
        stub_request(:get, "#{upstream_url}?artifactType=application%2Fvnd.example.test")
          .to_return(status: 200, body: '{"schemaVersion":2,"manifests":[]}')
      end

      it 'forwards artifactType as query parameter to upstream' do
        is_expected.to be_success
      end
    end

    context 'when upstream returns OCI-Filters-Applied header' do
      before do
        stub_request(:get, upstream_url)
          .to_return(
            status: 200,
            body: '{"schemaVersion":2,"manifests":[]}',
            headers: { 'OCI-Filters-Applied' => 'artifactType' }
          )
      end

      it 'includes the header value in the payload' do
        is_expected.to be_success
        expect(execute.payload[:filters_applied]).to eq('artifactType')
      end
    end

    context 'when upstream returns a Link header (pagination)' do
      before do
        stub_request(:get, upstream_url)
          .to_return(
            status: 200,
            body: '{"schemaVersion":2,"manifests":[]}',
            headers: { 'Link' => '</v2/alpine/referrers/sha256:abc?last=sha256:def>; rel="next"' }
          )
      end

      it 'does not forward the Link header to avoid leaking upstream hostnames' do
        is_expected.to be_success
        expect(execute.payload).not_to have_key(:link)
      end
    end

    context 'when no upstreams are configured' do
      before do
        allow(registry).to receive(:upstreams).and_return([])
      end

      it 'returns error with :no_upstreams reason' do
        is_expected.to be_error.and have_attributes(reason: :no_upstreams)
      end
    end

    context 'when upstream returns 401' do
      before do
        stub_request(:get, upstream_url).to_return(status: 401, body: '{}')
      end

      it 'returns error with :upstream_auth_error reason' do
        is_expected.to be_error.and have_attributes(reason: :upstream_auth_error)
      end
    end

    context 'when upstream returns 403' do
      before do
        stub_request(:get, upstream_url).to_return(status: 403, body: '{}')
      end

      it 'returns error with :upstream_auth_error reason' do
        is_expected.to be_error.and have_attributes(reason: :upstream_auth_error)
      end
    end

    context 'when upstream returns an unexpected status code' do
      before do
        stub_request(:get, upstream_url).to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns error with :upstream_not_available reason' do
        is_expected.to be_error.and have_attributes(reason: :upstream_not_available)
      end
    end

    context 'when upstream raises a network error' do
      before do
        stub_request(:get, upstream_url).to_raise(Net::OpenTimeout)
      end

      it 'returns error with :upstream_not_available reason' do
        is_expected.to be_error.and have_attributes(reason: :upstream_not_available)
      end
    end

    context 'when artifact_type exceeds maximum length' do
      let(:artifact_type) { 'a' * 256 }

      it 'returns error with :invalid_artifact_type reason' do
        is_expected.to be_error.and have_attributes(reason: :invalid_artifact_type)
      end
    end

    context 'when artifact_type has an invalid media-type format' do
      let(:artifact_type) { '<script>alert(1)</script>' }

      it 'returns error with :invalid_artifact_type reason' do
        is_expected.to be_error.and have_attributes(reason: :invalid_artifact_type)
      end
    end

    context 'when path is not present' do
      let(:path) { nil }

      it 'returns error with :path_not_present reason' do
        is_expected.to be_error.and have_attributes(reason: :path_not_present)
      end
    end

    context 'when upstream response exceeds the size limit' do
      before do
        stub_request(:get, upstream_url).to_raise(Gitlab::HTTP_V2::ResponseSizeTooLarge)
      end

      it 'returns error with :upstream_not_available reason' do
        is_expected.to be_error.and have_attributes(reason: :upstream_not_available)
      end
    end

    context 'when user is not authenticated' do
      let(:service) do
        described_class.new(registry: registry, current_user: nil, params: { path: path })
      end

      it 'returns error with :unauthorized reason' do
        is_expected.to be_error.and have_attributes(reason: :unauthorized)
      end
    end
  end
end
