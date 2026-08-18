# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual Registry routing', "routing", feature_category: :virtual_registry do
  describe 'Virtual Registries for Containers' do
    let(:registry_id) { '1' }
    let(:image) { 'alpine' }
    let(:tag) { 'latest' }
    let(:digest) { "sha256:#{'a' * 64}" }
    let(:sha) { 'sha256:abc123def456' }

    shared_examples 'routes correctly' do
      specify do
        expect(get(path))
          .to route_to(
            controller: 'virtual_registries/container',
            action: 'show',
            id: registry_id,
            path: expected_path
          )
      end
    end

    shared_examples 'does not route' do |method:|
      specify do
        expect(send(method, path))
          .not_to route_to(
            controller: 'virtual_registries/container',
            action: expected_action,
            id: registry_id,
            path: expected_path
          )
      end
    end

    shared_examples 'invalid manifest routes' do |method:, action:, path_suffix: ''|
      let(:expected_action) { action }

      context 'with invalid tag names' do
        where(:tag_name) do
          [
            ['-invalid'],
            ['a' * 129],
            ["md5:#{'a' * 32}"],
            ["sha256:#{'a' * 63}"],
            ["sha256:#{'A' * 64}"],
            ["sha256:#{'g' * 64}"]
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/alpine/manifests/#{tag_name}#{path_suffix}" }
          let(:expected_path) { "alpine/manifests/#{tag_name}" }

          it_behaves_like 'does not route', method: method
        end
      end

      context 'with invalid image name' do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/invalid*/manifests/#{tag}#{path_suffix}" }
        let(:expected_path) { "invalid*/manifests/#{tag}" }

        it_behaves_like 'does not route', method: method
      end
    end

    shared_examples 'invalid blob routes' do |method:, action:, path_suffix: ''|
      let(:expected_action) { action }

      context 'with invalid sha format' do
        where(:invalid_sha) do
          [
            ['invalid'],
            ['sha256:..%2F..']
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/alpine/blobs/#{invalid_sha}#{path_suffix}" }
          let(:expected_path) { "alpine/blobs/#{invalid_sha}" }

          it_behaves_like 'does not route', method: method
        end
      end

      context 'with invalid image name' do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/invalid*/blobs/#{sha}#{path_suffix}" }
        let(:expected_path) { "invalid*/blobs/#{sha}" }

        it_behaves_like 'does not route', method: method
      end
    end

    describe 'GET /v2/virtual_registries/container/:id/*path (manifests)' do
      where(:image_name, :identifier) do
        [
          ['alpine',          ref(:tag)],
          ['alpine',          ref(:digest)],
          ['library/alpine',  ref(:tag)],
          ['library/alpine',  ref(:digest)],
          ['foo/bar/baz/qux', ref(:tag)],
          ['foo/bar/baz/qux', ref(:digest)]
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/manifests/#{identifier}" }
        let(:expected_path) { "#{image_name}/manifests/#{identifier}" }

        it_behaves_like 'routes correctly'
      end

      context 'with valid tag characters' do
        where(:tag_name) do
          [
            ['v1.2.3'],
            ['feature-branch'],
            ['feature_branch'],
            ['_internal'],
            ['v1.2.3-rc.1_build.123']
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/manifests/#{tag_name}" }
          let(:expected_path) { "#{image}/manifests/#{tag_name}" }

          it_behaves_like 'routes correctly'
        end
      end

      it_behaves_like 'invalid manifest routes', method: :get, action: 'show'
    end

    describe 'GET /v2/virtual_registries/container/:id/*path (blobs)' do
      where(:image_name) do
        [
          ['alpine'],
          ['library/alpine'],
          ['foo/bar/baz/qux']
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/blobs/#{sha}" }
        let(:expected_path) { "#{image_name}/blobs/#{sha}" }

        it_behaves_like 'routes correctly'
      end

      context 'with full sha256 digest' do
        let(:full_digest) { "sha256:#{'a' * 64}" }
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image}/blobs/#{full_digest}" }
        let(:expected_path) { "#{image}/blobs/#{full_digest}" }

        it_behaves_like 'routes correctly'
      end

      it_behaves_like 'invalid blob routes', method: :get, action: 'show'
    end

    describe 'POST /v2/virtual_registries/container/:id/*path/upload (manifests)' do
      where(:image_name, :identifier) do
        [
          ['alpine',          ref(:tag)],
          ['alpine',          ref(:digest)],
          ['library/alpine',  ref(:tag)],
          ['library/alpine',  ref(:digest)],
          ['foo/bar/baz/qux', ref(:tag)],
          ['foo/bar/baz/qux', ref(:digest)]
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/manifests/#{identifier}/upload" }
        let(:expected_path) { "#{image_name}/manifests/#{identifier}" }

        specify do
          expect(post(path))
            .to route_to(
              controller: 'virtual_registries/container',
              action: 'upload',
              id: registry_id,
              path: expected_path
            )
        end
      end

      it_behaves_like 'invalid manifest routes', method: :post, action: 'upload', path_suffix: '/upload'
    end

    describe 'GET /v2/virtual_registries/container/:id/*path (referrers)' do
      where(:image_name) do
        [
          ['alpine'],
          ['library/alpine'],
          ['foo/bar/baz/qux']
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/referrers/#{digest}" }
        let(:expected_path) { "#{image_name}/referrers/#{digest}" }

        specify do
          expect(get(path))
            .to route_to(
              controller: 'virtual_registries/container',
              action: 'referrers',
              id: registry_id,
              path: expected_path
            )
        end
      end

      context 'with an invalid digest (catch-all)' do
        where(:bad_digest) do
          [
            ['not-a-digest'],
            ['justplaintext'],
            ['sha256:']
          ]
        end

        with_them do
          let(:path) { "/v2/virtual_registries/container/#{registry_id}/alpine/referrers/#{bad_digest}" }

          specify do
            expect(get(path))
              .to route_to(
                controller: 'virtual_registries/container',
                action: 'referrers_not_found',
                id: registry_id,
                image: 'alpine',
                tag: bad_digest
              )
          end
        end
      end
    end

    describe 'POST /v2/virtual_registries/container/:id/*path/upload (blobs)' do
      where(:image_name) do
        [
          ['alpine'],
          ['library/alpine'],
          ['foo/bar/baz/qux']
        ]
      end

      with_them do
        let(:path) { "/v2/virtual_registries/container/#{registry_id}/#{image_name}/blobs/#{sha}/upload" }
        let(:expected_path) { "#{image_name}/blobs/#{sha}" }

        specify do
          expect(post(path))
            .to route_to(
              controller: 'virtual_registries/container',
              action: 'upload',
              id: registry_id,
              path: expected_path
            )
        end
      end

      it_behaves_like 'invalid blob routes', method: :post, action: 'upload', path_suffix: '/upload'
    end
  end
end
