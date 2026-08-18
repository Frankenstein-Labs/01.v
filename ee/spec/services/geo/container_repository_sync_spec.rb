# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ContainerRepositorySync, :geo, feature_category: :geo_replication do
  let_it_be(:group, freeze: true) { create(:group, name: 'group') }
  let_it_be(:project, freeze: true) { create(:project, path: 'test', group: group) }

  let(:container_repository) { create(:container_repository, name: 'my_image', project: project) }
  let(:primary_api_url) { 'http://primary.registry.gitlab' }
  let(:secondary_api_url) { 'http://secondary.registry.gitlab' }
  let(:primary_repository_url) { "#{primary_api_url}/v2/#{container_repository.path}" }
  let(:secondary_repository_url) { "#{secondary_api_url}/v2/#{container_repository.path}" }

  # Break symbol will be removed if JSON encode/decode operation happens so we use this
  # to prove that it does not happen and we preserve original human readable JSON
  let(:manifest) do
    "{" \
      "\n\"schemaVersion\":2," \
      "\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\"," \
      "\n\"layers\":[" \
        "{\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\",\n\"size\":3333,\n\"digest\":\"sha256:3333\"}," \
        "{\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\",\n\"size\":4444,\n\"digest\":\"sha256:4444\"}," \
        "{\n\"mediaType\":\"application/vnd.docker.image.rootfs.foreign.diff.tar.gzip\",\n\"size\":5555,\n\"digest\":\"sha256:5555\",\n\"urls\":[\"https://foo.bar/v2/zoo/blobs/sha256:5555\"]}" \
      "]" \
    "}"
  end

  let(:manifest_list) do
    %(
      {
        "schemaVersion":2,
        "mediaType":"application/vnd.docker.distribution.manifest.list.v2+json",
        "manifests":[
          {
            "mediaType":"application/vnd.docker.distribution.manifest.v2+json",
            "size":6666,
            "digest":"sha256:6666",
            "platform":
              {
                "architecture":"arm64","os":"linux"
              }
          }
        ]
      }
    )
  end

  before do
    stub_container_registry_config(enabled: true, api_url: secondary_api_url)
    stub_registry_replication_config(enabled: true, primary_api_url: primary_api_url)
    stub_connected(true)
  end

  shared_context 'with the Gitlab API returning tags' do
    before do
      allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(true)
      allow(container_repository).to receive(:each_tags_page).and_call_original
      allow(container_repository.gitlab_api_client).to receive(:tags).and_return(
        { response_body: ::Gitlab::Json.parse(response_body) }
      )
    end
  end

  def stub_repository_tags_requests(repository_url, tags)
    stub_request(:get, "#{repository_url}/tags/list?n=#{::ContainerRegistry::Client::DEFAULT_TAGS_PAGE_SIZE}")
      .to_return(
        status: 200,
        body: Gitlab::Json.dump(tags: tags.keys),
        headers: { 'Content-Type' => 'application/json' })

    tags.each do |tag, digest|
      stub_request(:head, "#{repository_url}/manifests/#{tag}")
        .to_return(status: 200, body: "", headers: { DependencyProxy::Manifest::DIGEST_HEADER => digest })
    end
  end

  def stub_raw_manifest_request(repository_url, tag, manifest)
    stub_request(:get, "#{repository_url}/manifests/#{tag}")
      .to_return(status: 200, body: manifest, headers: {})
  end

  def stub_raw_manifest_list_request(repository_url, tag, manifest_list)
    stub_request(:get, "#{repository_url}/manifests/#{tag}")
      .to_return(status: 200, body: manifest_list, headers: {})
  end

  def stub_push_manifest_request(repository_url, tag, manifest)
    stub_request(:put, "#{repository_url}/manifests/#{tag}")
      .with(body: manifest)
      .to_return(status: 200, body: "", headers: {})
  end

  def stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, blobs)
    blobs.each do |digest, missing|
      stub_request(:head, "#{secondary_repository_url}/blobs/#{digest}")
        .to_return(status: (missing ? 404 : 200), body: "", headers: {})

      next unless missing

      stub_request(:get, "#{primary_repository_url}/blobs/#{digest}")
        .to_return(status: 200, body: File.new(Rails.root.join('ee/spec/fixtures/sample_schema.json')), headers: {})
    end
  end

  def stub_manifest_exists_request(repository_url, reference, exists)
    stub_request(:head, "#{repository_url}/manifests/#{reference}")
      .to_return(status: (exists ? 200 : 404), body: "", headers: {})
  end

  def stub_connected(connected)
    allow_next_instance_of(ContainerRegistry::Client) do |client|
      allow(client).to receive(:connected?).and_return(connected)
    end
  end

  describe '#execute' do
    subject { described_class.new(container_repository) }

    context 'single manifest' do
      before do
        stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
        stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', manifest)
        stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })
        stub_push_manifest_request(secondary_repository_url, 'tag-to-sync', manifest)
      end

      shared_examples 'determining the list of tags to sync and to remove correctly' do
        it 'determines list of tags to sync and to remove correctly' do
          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).not_to receive(:push_blob).with('sha256:4444', anything, anything)
          expect(container_repository).not_to receive(:push_blob).with('sha256:5555', anything, anything)
          expect(container_repository).to receive(:delete_tag).with('sha256:2222')

          subject.execute
        end
      end

      shared_examples 'removing secondary tags without failure when primary repository does not have tags' do
        it 'removes secondary tags and does not fail' do
          stub_repository_tags_requests(primary_repository_url, {})
          expect(container_repository).to receive(:delete_tag).with('sha256:2222')
          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, { 'tag-to-remove' => 'sha256:2222' })
        end

        it_behaves_like 'determining the list of tags to sync and to remove correctly'
        it_behaves_like 'removing secondary tags without failure when primary repository does not have tags'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { [{ name: 'tag-to-remove', digest: 'sha256:2222' }].to_json }

        it_behaves_like 'determining the list of tags to sync and to remove correctly'
        it_behaves_like 'removing secondary tags without failure when primary repository does not have tags'
      end

      context 'when an orphan secondary tag has no resolvable digest' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(primary_repository_url, {})
          stub_repository_tags_requests(secondary_repository_url, { 'orphan-tag' => nil })
        end

        it 'falls back to deleting the tag by name' do
          expect(container_repository).to receive(:delete_tag).with('orphan-tag')
          subject.execute
        end
      end
    end

    context 'manifest list' do
      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:6666', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'image without mediaType parameter' do
      let(:manifest_no_media_type) do
        %(
          {
            "schemaVersion":2,
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"}
            ]
         }
        )
      end

      shared_examples 'pushing the correct blobs and manifests without failure' do
        it 'pushes the correct blobs and manifests without failure' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', manifest_no_media_type)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true })
          stub_push_manifest_request(secondary_repository_url, 'tag-to-sync', manifest_no_media_type)

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests without failure'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests without failure'
      end
    end

    context 'oci manifest list' do
      let(:oci_manifest) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.manifest.v1+json",
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"},
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":4444,"digest":"sha256:4444"},
              {"mediaType":"application/vnd.docker.image.rootfs.foreign.diff.tar.gzip","size":5555,"digest":"sha256:5555","urls":["https://foo.bar/v2/zoo/blobs/sha256:5555"]}
            ]
         }
        )
      end

      let(:oci_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.manifest.v1+json",
                "size":6666,
                "digest":"sha256:6666",
                "platform":
                  {
                    "architecture":"arm64","os":"linux"
                  }
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', oci_manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', oci_manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with(
            'sha256:6666', anything, ContainerRegistry::Client::OCI_MANIFEST_V1_TYPE
          )
          expect(container_repository).to receive(:push_manifest).with(
            'tag-to-sync', anything, ContainerRegistry::Client::OCI_DISTRIBUTION_INDEX_TYPE
          )

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'oci manifest list with a submanifest body that omits mediaType' do
      let(:oci_manifest_no_media_type) do
        %(
          {
            "schemaVersion":2,
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"}
            ]
          }
        )
      end

      let(:oci_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.manifest.v1+json",
                "size":6666,
                "digest":"sha256:6666",
                "platform":{"architecture":"arm64","os":"linux"}
              }
            ]
          }
        )
      end

      shared_examples 'falling back to the descriptor mediaType' do
        it 'pushes the submanifest with the descriptor mediaType', :aggregate_failures do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', oci_manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', oci_manifest_no_media_type)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with(
            'sha256:6666', oci_manifest_no_media_type, ContainerRegistry::Client::OCI_MANIFEST_V1_TYPE
          )
          expect(container_repository).to receive(:push_manifest).with(
            'tag-to-sync', oci_manifest_list, ContainerRegistry::Client::OCI_DISTRIBUTION_INDEX_TYPE
          )

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'falling back to the descriptor mediaType'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'falling back to the descriptor mediaType'
      end
    end

    context 'oci manifest list with a submanifest body whose mediaType differs from the descriptor' do
      let(:oci_manifest_with_docker_body) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.docker.distribution.manifest.v2+json",
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"}
            ]
          }
        )
      end

      let(:oci_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.manifest.v1+json",
                "size":6666,
                "digest":"sha256:6666",
                "platform":{"architecture":"arm64","os":"linux"}
              }
            ]
          }
        )
      end

      shared_examples 'preferring the body mediaType over the descriptor' do
        it 'pushes the submanifest with the body mediaType', :aggregate_failures do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', oci_manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', oci_manifest_with_docker_body)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with(
            'sha256:6666', oci_manifest_with_docker_body, ContainerRegistry::Client::DOCKER_DISTRIBUTION_MANIFEST_V2_TYPE
          )
          expect(container_repository).to receive(:push_manifest).with(
            'tag-to-sync', oci_manifest_list, ContainerRegistry::Client::OCI_DISTRIBUTION_INDEX_TYPE
          )

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'preferring the body mediaType over the descriptor'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'preferring the body mediaType over the descriptor'
      end
    end

    context 'buildkit cache images' do
      let(:buildcache_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.layer.v1.tar+gzip",
                "digest":"sha256:3333",
                "size":24803024,
                "annotations":{
                   "buildkit/createdat":"2022-06-17T16:44:22.638028085Z",
                   "containerd.io/uncompressed":"sha256:65feea9638f81cb1fab4ede714f970bb8453cd1a2aa23860d2bb3fdcb960068b"
                }
              },
              {
                "mediaType":"application/vnd.buildkit.cacheconfig.v0",
                "digest":"sha256:4444",
                "size":1753
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', buildcache_manifest_list)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'OCI image with artifact' do
      let(:artifact_manifest) do
        %(
          {
            "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
            "artifactType": "application/vnd.example.sbom.v1",
            "blobs": [
              {
                "mediaType": "application/gzip",
                "size": 123,
                "digest": "sha256:8792"
              }
            ],
            "subject": {
              "mediaType": "application/vnd.oci.image.manifest.v1+json",
              "size": 1234,
              "digest": "sha256:cc06a2839488b8bd2a2b99dcdc03d5cfd818eed72ad08ef3cc197aac64c0d0a0"
            },
            "annotations": {
              "org.opencontainers.artifact.created": "2022-01-01T14:42:55Z",
              "org.example.sbom.format": "json"
            }
          }
        )
      end

      let(:manifest_list_with_artifacts) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
                "size": 7682,
                "digest": "sha256:6015",
                "artifactType": "application/example",
                "annotations": {
                    "com.example.artifactKey1": "value1",
                    "com.example.artifactKey2": "value2"
                  }
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', manifest_list_with_artifacts)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6015', artifact_manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:8792' => true })

          expect(container_repository).to receive(:push_blob).with('sha256:8792', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:6015', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      it 'raises an error with a bad connection' do
        stub_connected(false)
        expect { subject.execute }.to raise_error.with_message('No valid connection to primary registry')
      end
    end

    context 'bare artifact manifest (no layers, manifests, or blobs)' do
      let(:bare_artifact_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.example",
              "digest": "sha256:abc123",
              "size": 12
            },
            "subject": {
              "mediaType": "application/vnd.oci.image.manifest.v1+json",
              "digest": "sha256:def456",
              "size": 34
            }
          }
        )
      end

      # The manifest above references a subject (sha256:def456) via the OCI 1.1
      # `subject` field. The subject is the signed image and must be pushed to the
      # secondary before the artifact manifest, otherwise the registry rejects the
      # push with MANIFEST_BLOB_UNKNOWN.
      let(:subject_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:5b1ec7",
              "size": 7
            }
          }
        )
      end

      shared_examples 'syncing a bare artifact manifest without error' do
        it 'pushes the subject before the artifact manifest', :aggregate_failures do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', bare_artifact_manifest)
          stub_raw_manifest_request(primary_repository_url, 'sha256:def456', subject_manifest)
          stub_manifest_exists_request(secondary_repository_url, 'sha256:def456', false)
          stub_missing_blobs_requests(
            primary_repository_url, secondary_repository_url,
            { 'sha256:abc123' => true, 'sha256:5b1ec7' => true }
          )

          expect(container_repository).to receive(:push_blob).with('sha256:abc123', anything, anything)
          expect(container_repository).to receive(:push_blob).with('sha256:5b1ec7', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:def456', anything, anything).ordered
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything).ordered

          expect { subject.execute }.not_to raise_error
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'syncing a bare artifact manifest without error'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'syncing a bare artifact manifest without error'
      end
    end

    # Cosign/Sigstore signatures use the OCI 1.1 referrers convention: the
    # signature is published under a `sha256-<image-digest>` tag and references
    # the signed image (its subject). The subject must exist on the secondary
    # before the signature can be pushed.
    context 'cosign signature tag referencing a subject by tag name' do
      let(:subject_hex) { 'a1b2c3d4' * 8 }
      let(:cosign_tag) { "sha256-#{subject_hex}" }
      let(:subject_digest) { "sha256:#{subject_hex}" }

      # A cosign signature manifest carries no `subject` field; the subject is
      # encoded only in the tag name.
      let(:cosign_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            }
          }
        )
      end

      let(:subject_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "config": {
              "mediaType": "application/vnd.docker.container.image.v1+json",
              "digest": "sha256:5b1ec",
              "size": 100
            }
          }
        )
      end

      shared_examples 'syncing the subject before the signature' do
        it 'pushes the subject image before the signature tag', :aggregate_failures do
          stub_repository_tags_requests(primary_repository_url, { cosign_tag => 'sha256:5161a' })
          stub_raw_manifest_request(primary_repository_url, cosign_tag, cosign_manifest)
          stub_raw_manifest_request(primary_repository_url, subject_digest, subject_manifest)
          stub_manifest_exists_request(secondary_repository_url, subject_digest, false)
          stub_missing_blobs_requests(
            primary_repository_url, secondary_repository_url,
            { 'sha256:c051f' => false, 'sha256:5b1ec' => false }
          )

          expect(container_repository).to receive(:push_manifest).with(subject_digest, anything, anything).ordered
          expect(container_repository).to receive(:push_manifest).with(cosign_tag, anything, anything).ordered

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'syncing the subject before the signature'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'syncing the subject before the signature'
      end
    end

    context 'cosign signature tag whose subject is a multi-arch image index' do
      let(:subject_hex) { 'd4c3b2a1' * 8 }
      let(:cosign_tag) { "sha256-#{subject_hex}" }
      let(:subject_digest) { "sha256:#{subject_hex}" }

      let(:cosign_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            }
          }
        )
      end

      # The subject is itself a multi-arch OCI index; its platform submanifests
      # must be pushed before the index itself.
      let(:subject_index) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.index.v1+json",
            "manifests": [
              {
                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                "digest": "sha256:a4c41",
                "size": 528,
                "platform": { "architecture": "amd64", "os": "linux" }
              }
            ]
          }
        )
      end

      let(:platform_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:a4cfg",
              "size": 7
            }
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'pushes the platform submanifest, then the subject index, then the signature', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { cosign_tag => 'sha256:5161a' })
        stub_raw_manifest_request(primary_repository_url, cosign_tag, cosign_manifest)
        stub_raw_manifest_list_request(primary_repository_url, subject_digest, subject_index)
        stub_raw_manifest_request(primary_repository_url, 'sha256:a4c41', platform_manifest)
        stub_manifest_exists_request(secondary_repository_url, subject_digest, false)
        stub_missing_blobs_requests(
          primary_repository_url, secondary_repository_url,
          { 'sha256:c051f' => false, 'sha256:a4cfg' => false }
        )

        expect(container_repository).to receive(:push_manifest).with('sha256:a4c41', anything, anything).ordered
        expect(container_repository).to receive(:push_manifest).with(subject_digest, anything, anything).ordered
        expect(container_repository).to receive(:push_manifest).with(cosign_tag, anything, anything).ordered

        subject.execute
      end
    end

    context 'cosign signature tag whose subject already exists on the secondary' do
      let(:subject_hex) { 'beefcafe' * 8 }
      let(:cosign_tag) { "sha256-#{subject_hex}" }
      let(:subject_digest) { "sha256:#{subject_hex}" }

      let(:cosign_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            }
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'does not re-push the subject but still pushes the signature', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { cosign_tag => 'sha256:5161a' })
        stub_raw_manifest_request(primary_repository_url, cosign_tag, cosign_manifest)
        stub_manifest_exists_request(secondary_repository_url, subject_digest, true)
        stub_missing_blobs_requests(
          primary_repository_url, secondary_repository_url, { 'sha256:c051f' => false }
        )

        expect(container_repository).not_to receive(:push_manifest).with(subject_digest, anything, anything)
        expect(container_repository).to receive(:push_manifest).with(cosign_tag, anything, anything)

        subject.execute
      end
    end

    # The subject can be absent on the primary: an orphan signature whose signed
    # image was deleted and GC'd (cleanup policies skip `sha256-*` tags so
    # signatures outlive their subjects), or a normal image whose tag merely
    # matches the cosign naming convention. The subject fetch 404s; the referrer
    # must still be pushed so the tag does not churn the verification state.
    context 'cosign tag whose subject is absent on the primary' do
      let(:subject_hex) { 'deadbeef' * 8 }
      let(:cosign_tag) { "sha256-#{subject_hex}" }
      let(:subject_digest) { "sha256:#{subject_hex}" }

      let(:cosign_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            }
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'pushes the referrer without syncing the subject and does not log an error', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { cosign_tag => 'sha256:5161a' })
        stub_raw_manifest_request(primary_repository_url, cosign_tag, cosign_manifest)
        stub_manifest_exists_request(secondary_repository_url, subject_digest, false)
        stub_request(:get, "#{primary_repository_url}/manifests/#{subject_digest}")
          .to_return(status: 404, body: "", headers: {})
        stub_missing_blobs_requests(
          primary_repository_url, secondary_repository_url, { 'sha256:c051f' => false }
        )

        expect(container_repository).not_to receive(:push_manifest).with(subject_digest, anything, anything)
        expect(container_repository).to receive(:push_manifest).with(cosign_tag, anything, anything)
        expect(subject).not_to receive(:log_error)

        subject.execute
      end
    end

    # A `subject` block can carry a non-string `digest` (malformed manifest).
    # Deriving a digest from it would feed garbage into the fetch path, so the
    # subject is skipped and only the referrer is pushed.
    context 'manifest with a non-string subject digest' do
      let(:tag_name) { 'tag-to-sync' }

      let(:manifest_with_bad_subject) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            },
            "subject": { "digest": 123 }
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'pushes the referrer without attempting a subject sync', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { tag_name => 'sha256:5161a' })
        stub_raw_manifest_request(primary_repository_url, tag_name, manifest_with_bad_subject)
        stub_missing_blobs_requests(
          primary_repository_url, secondary_repository_url, { 'sha256:c051f' => false }
        )

        expect(container_repository).to receive(:push_manifest).with(tag_name, anything, anything)
        expect(subject).not_to receive(:log_error)

        subject.execute
      end
    end

    # A manifest can declare an OCI index media type while omitting the
    # `manifests` key (malformed or empty index). Guarding avoids a
    # NoMethodError that the per-tag rescue would otherwise swallow, silently
    # skipping the tag.
    context 'OCI index manifest with no submanifests key' do
      let(:empty_index_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.index.v1+json"
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'syncs without raising and pushes the tag', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
        stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', empty_index_manifest)

        expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

        expect { subject.execute }.not_to raise_error
      end
    end

    context 'cosign signature tag whose subject is an index with no submanifests key' do
      let(:subject_hex) { 'feedface' * 8 }
      let(:cosign_tag) { "sha256-#{subject_hex}" }
      let(:subject_digest) { "sha256:#{subject_hex}" }

      let(:cosign_manifest) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
              "mediaType": "application/vnd.oci.image.config.v1+json",
              "digest": "sha256:c051f",
              "size": 233
            }
          }
        )
      end

      let(:empty_index_subject) do
        %(
          {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.index.v1+json"
          }
        )
      end

      before do
        allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        stub_repository_tags_requests(secondary_repository_url, {})
      end

      it 'syncs the subject without raising and pushes both manifests', :aggregate_failures do
        stub_repository_tags_requests(primary_repository_url, { cosign_tag => 'sha256:5161a' })
        stub_raw_manifest_request(primary_repository_url, cosign_tag, cosign_manifest)
        stub_raw_manifest_request(primary_repository_url, subject_digest, empty_index_subject)
        stub_manifest_exists_request(secondary_repository_url, subject_digest, false)
        stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:c051f' => false })

        expect(container_repository).to receive(:push_manifest).with(subject_digest, anything, anything).ordered
        expect(container_repository).to receive(:push_manifest).with(cosign_tag, anything, anything).ordered

        expect { subject.execute }.not_to raise_error
      end
    end

    describe '#client' do
      it 'caches the client' do
        client = subject.send(:client)
        client1 = subject.send(:client)
        client2 = nil

        travel_to(Time.current + Gitlab::CurrentSettings.container_registry_token_expire_delay.minutes) do
          client2 = subject.send(:client)
        end

        expect(client1.object_id).to be(client.object_id)
        expect(client2.object_id).not_to be(client.object_id)
      end
    end

    context 'when tag sync fails' do
      let(:tag) { { name: 'latest', digest: 'sha256:123' } }

      before do
        client = subject.send(:client)
        allow(client).to receive(:connected?).and_return(true)
        allow(subject).to receive(:tags_to_sync).and_return([tag])
        allow(subject).to receive(:tags_to_remove).and_return([])
        allow(subject).to receive(:sync_tag).with(tag).and_raise(StandardError.new("Sync failed"))
      end

      it 'logs the error and continues execution', :aggregate_failures do
        expect(subject).to receive(:log_error).with("Error while syncing tag latest: Sync failed")

        result = subject.execute

        expect(result).to be true
      end

      it 'logs multiple errors if multiple tags fail', :aggregate_failures do
        multiple_tags = [
          { name: 'latest', digest: 'sha256:123' },
          { name: 'v1.0', digest: 'sha256:456' }
        ]

        allow(subject).to receive(:tags_to_sync).and_return(multiple_tags)
        allow(subject).to receive(:sync_tag).and_raise(StandardError.new("Sync failed"))

        multiple_tags.each do |tag|
          expect(subject).to receive(:log_error).with("Error while syncing tag #{tag[:name]}: Sync failed")
        end

        expect { subject.execute }.not_to raise_error
      end
    end

    context 'when tag removal fails' do
      let(:tag) { { name: 'latest', digest: 'sha256:123' } }

      before do
        client = subject.send(:client)
        allow(client).to receive(:connected?).and_return(true)
        allow(subject).to receive(:tags_to_sync).and_return([])
        allow(subject).to receive(:tags_to_remove).and_return([tag])

        # Simulate the error during tag removal
        allow(container_repository).to receive(:delete_tag)
          .with(tag[:digest])
          .and_raise(StandardError.new("Failed to remove tag"))
      end

      it 'logs the error message', :aggregate_failures do
        expect(subject).to receive(:log_error)
          .with("Error while removing tag latest: Failed to remove tag")

        expect(subject.execute).to be true
      end

      it 'continues execution after logging the error' do
        expect { subject.execute }.not_to raise_error
      end

      it 'processes all tags in tags_to_remove even if one fails' do
        another_tag = { name: 'v1.0', digest: 'sha256:456' }
        allow(subject).to receive(:tags_to_remove).and_return([tag, another_tag])

        allow(container_repository).to receive(:delete_tag)
          .with(tag[:digest])
          .and_raise(StandardError.new("Failed to remove tag"))
        allow(container_repository).to receive(:delete_tag)
          .with(another_tag[:digest])
          .and_return(true)

        expect(container_repository).to receive(:delete_tag).twice
        expect(subject).to receive(:log_error).once

        subject.execute
      end
    end
  end

  describe '#subject_digest' do
    using RSpec::Parameterized::TableSyntax

    let(:service) { described_class.new(container_repository) }

    where(:scenario, :reference, :parsed, :expected) do
      'subject field present'               | 'any-tag'                 | { 'subject' => { 'digest' => 'sha256:fff' } } | 'sha256:fff'
      'subject field wins over cosign name' | "sha256-#{'a' * 64}"      | { 'subject' => { 'digest' => 'sha256:fff' } } | 'sha256:fff'
      'bare cosign tag name'                | "sha256-#{'a' * 64}"      | {}                                            | "sha256:#{'a' * 64}"
      'cosign .sig tag name'                | "sha256-#{'a' * 64}.sig"  | {}                                            | "sha256:#{'a' * 64}"
      'cosign .att tag name'                | "sha256-#{'b' * 64}.att"  | {}                                            | "sha256:#{'b' * 64}"
      'cosign .sbom tag name'               | "sha256-#{'c' * 64}.sbom" | {}                                            | "sha256:#{'c' * 64}"
      'ordinary tag name'                   | 'latest'                  | {}                                            | nil
      'sha256- prefix but not 64 hex'       | 'sha256-deadbeef'         | {}                                            | nil
      'nil manifest with cosign name'       | "sha256-#{'d' * 64}"      | nil                                           | "sha256:#{'d' * 64}"
      'nil manifest with ordinary name'     | 'latest'                  | nil                                           | nil
    end

    with_them do
      it 'derives the subject digest' do
        expect(service.send(:subject_digest, reference, parsed)).to eq(expected)
      end
    end
  end

  describe '#sync_subject_manifest' do
    let(:service) { described_class.new(container_repository) }

    it 'stops and logs when the subject chain exceeds the max depth', :aggregate_failures do
      expect(service).to receive(:log_error).with(/exceeded max depth/)
      expect(container_repository).not_to receive(:manifest_exists?)

      service.send(:sync_subject_manifest, 'sha256:whatever', described_class::MAX_SUBJECT_DEPTH + 1)
    end
  end
end
