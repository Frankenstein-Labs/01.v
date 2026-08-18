# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Upstream::Test, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let(:params) { { group_path: group.full_path, url: 'http://example.com' } }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  specify { expect(described_class).to require_graphql_authorizations(:create_virtual_registry) }

  describe '#resolve' do
    subject(:resolve) { mutation.resolve(**params) }

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(container_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    shared_examples 'raises resource not available error' do
      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user has permission' do
      before_all do
        group.add_owner(current_user)
      end

      before do
        allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
          allow(upstream_instance).to receive(:test).and_return({ success: true })
        end
      end

      it 'returns a successful result' do
        expect(resolve).to eq({ success: true, errors: [] })
      end

      context 'with username and password' do
        let(:params) do
          { group_path: group.full_path, url: 'http://example.com', username: 'user', password: 'test' }
        end

        it 'returns a successful result' do
          expect(resolve).to eq({ success: true, errors: [] })
        end
      end

      context 'when test returns error' do
        before do
          allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
            allow(upstream_instance).to receive(:test).and_return({ success: false, result: 'Error: 500' })
          end
        end

        it 'returns the error details' do
          expect(resolve).to eq({ success: false, errors: ['Error: 500'] })
        end
      end

      context 'when the upstream has validation errors' do
        let(:params) { { group_path: group.full_path, url: 'not-a-url' } }

        it 'returns the validation errors' do
          expect(resolve[:success]).to be(false)
          expect(resolve[:errors]).to be_present
        end
      end

      context 'when the virtual registries setting enabled is false' do
        before do
          allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
            :virtual_registries_setting, :disabled, group: group))
        end

        it_behaves_like 'raises resource not available error'
      end

      context 'with an existing upstream ID' do
        let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
        let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }
        let(:params) { { id: upstream.to_global_id } }

        before do
          allow_next_found_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
            allow(upstream_instance).to receive(:test).and_return({ success: true })
          end
        end

        it 'returns a successful result' do
          expect(resolve).to eq({ success: true, errors: [] })
        end

        context 'when test returns error' do
          before do
            allow_next_found_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: false, result: 'Error: 500' })
            end
          end

          it 'returns the error details' do
            expect(resolve).to eq({ success: false, errors: ['Error: 500'] })
          end
        end

        context 'when the virtual registries setting enabled is false' do
          before do
            allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
              :virtual_registries_setting, :disabled, group: group))
          end

          it_behaves_like 'raises resource not available error'
        end
      end

      context 'with a non-existent upstream ID' do
        let(:params) do
          { id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
            model_name: 'VirtualRegistries::Container::Upstream') }
        end

        it_behaves_like 'raises resource not available error'
      end
    end

    context 'when user has no permission' do
      before_all do
        group.add_guest(current_user)
      end

      it_behaves_like 'raises resource not available error'
    end

    context 'with container_virtual_registries feature flag turned off' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it_behaves_like 'raises resource not available error'
    end

    context 'when container_virtual_registry licensed feature is unavailable' do
      before do
        stub_licensed_features(container_virtual_registry: false)
      end

      it_behaves_like 'raises resource not available error'
    end
  end

  describe '#ready?' do
    context 'when neither id nor group_path and url are provided' do
      let(:params) { {} }

      it 'raises an argument error' do
        expect { mutation.ready?(**params) }.to raise_error(
          Gitlab::Graphql::Errors::ArgumentError,
          'Either id or groupPath and url are required'
        )
      end
    end

    context 'when only group_path is provided without url' do
      let(:params) { { group_path: group.full_path } }

      it 'raises an argument error' do
        expect { mutation.ready?(**params) }.to raise_error(
          Gitlab::Graphql::Errors::ArgumentError,
          'Either id or groupPath and url are required'
        )
      end
    end
  end
end
