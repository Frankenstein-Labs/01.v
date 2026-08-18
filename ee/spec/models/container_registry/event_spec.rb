# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Event do
  using RSpec::Parameterized::TableSyntax
  include ::EE::GeoHelpers

  let_it_be(:group) { create(:group, name: 'group') }
  let_it_be(:project) { create(:project, path: 'test', namespace: group) }

  shared_examples 'creating a geo event' do
    it 'creates geo event' do
      expect { subject }
        .to change { ::Geo::Event.count }.by(1)
    end
  end

  shared_examples 'not creating a geo event' do
    it 'does not create geo event' do
      expect { subject }
        .not_to change { ::Geo::Event.count }
    end
  end

  context 'when the container registry is enabled' do
    before do
      stub_container_registry_config(enabled: true)
    end

    describe '#handle!' do
      context 'geo event' do
        let_it_be(:container_repository) { create(:container_repository, name: 'container', project: project) }
        let_it_be(:primary_node) { create(:geo_node, :primary) }
        let_it_be(:secondary_node) { create(:geo_node) }

        let(:raw_event) { { 'action' => action, 'target' => target } }

        subject { described_class.new(raw_event).handle! }

        before do
          stub_current_geo_node(primary_node)
        end

        context 'with a respository target' do
          let(:target) do
            {
              'mediaType' => ContainerRegistry::Client::DOCKER_DISTRIBUTION_MANIFEST_V2_TYPE,
              'repository' => repository_path
            }
          end

          where(:repository_path, :action, :example_name) do
            'group/test/container' | 'push' | 'creating a geo event'
            'group/test/container' | 'delete' | 'creating a geo event'
            'foo/bar' | 'push' | 'not creating a geo event'
            'foo/bar' | 'delete' | 'not creating a geo event'
          end

          with_them do
            it_behaves_like params[:example_name]
          end
        end

        context 'with a tag target' do
          let(:target) do
            {
              'mediaType' => ContainerRegistry::Client::DOCKER_DISTRIBUTION_MANIFEST_V2_TYPE,
              'repository' => repository_path,
              'tag' => 'latest'
            }
          end

          where(:repository_path, :action, :example_name) do
            'group/test/container' | 'push' | 'creating a geo event'
            'group/test/container' | 'delete' | 'creating a geo event'
            'foo/bar' | 'push' | 'not creating a geo event'
            'foo/bar' | 'delete' | 'not creating a geo event'
          end

          with_them do
            it_behaves_like params[:example_name]
          end

          context 'without media type' do
            let(:action) { 'push' }
            let(:repository_path) { 'group/test/container_repository' }
            let(:target) { super().without('mediaType') }

            it_behaves_like 'not creating a geo event'
          end
        end
      end

      context 'publish internal event' do
        let(:repository) { project.full_path }
        let(:target) do
          {
            'mediaType' => ContainerRegistry::Client::DOCKER_DISTRIBUTION_MANIFEST_V2_TYPE,
            'tag' => 'latest',
            'repository' => repository
          }
        end

        let(:raw_event) { { 'action' => action, 'target' => target } }

        subject(:handle!) { described_class.new(raw_event).handle! }

        context 'when action is push' do
          let(:action) { 'push' }

          shared_context 'with project present' do
            let_it_be(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

            let(:image_path) { "#{Gitlab.config.registry.host_port}/#{repository}:latest" }
            let(:key_file) { Tempfile.new('keypath') }

            before do
              allow(Gitlab.config.registry).to receive_messages(enabled: true, issuer: 'rspec', key: key_file.path)
              allow(OpenSSL::PKey::RSA).to receive(:new).and_return(rsa_key)

              allow_next_instance_of(JSONWebToken::RSAToken) do |instance|
                allow(instance).to receive(:key).and_return(rsa_key)
              end
            end
          end

          shared_examples 'publishing event' do
            it 'publishes an event' do
              expect { handle! }
                .to publish_event(::ContainerRegistry::ImagePushedEvent)
                      .with(event_data)
            end
          end

          context 'when project is present' do
            include_context 'with project present'

            let(:repository_path) { "#{Gitlab.config.registry.host_port}/#{repository}" }
            let(:event_data) do
              { project_id: project.id, image: image_path, repository: repository_path, tag: 'latest' }
            end

            include_examples 'publishing event'
          end

          context 'when project is not present' do
            let(:repository) { 'does/not/exist' }

            it 'does not publish an event' do
              expect { handle! }
                .not_to publish_event(::ContainerRegistry::ImagePushedEvent)
            end
          end
        end

        context 'when action is not push' do
          let(:action) { 'pull' }

          it 'does not publish an event' do
            expect { handle! }
              .not_to publish_event(::ContainerRegistry::ImagePushedEvent)
          end
        end
      end
    end
  end

  context 'when the container registry is disabled' do
    before do
      stub_container_registry_config(enabled: false)
    end

    describe '#handle!' do
      context 'geo event' do
        let_it_be(:container_repository) { create(:container_repository, name: 'container', project: project) }
        let_it_be(:primary_node) { create(:geo_node, :primary) }

        let(:target) do
          {
            'mediaType' => ContainerRegistry::Client::DOCKER_DISTRIBUTION_MANIFEST_V2_TYPE,
            'repository' => 'group/test/container'
          }
        end

        let(:raw_event) { { 'action' => action, 'target' => target } }

        subject(:handle!) { described_class.new(raw_event).handle! }

        before do
          stub_current_geo_node(primary_node)
        end

        where(:action) { %w[push delete] }

        with_them do
          it_behaves_like 'not creating a geo event'
        end
      end
    end
  end
end
