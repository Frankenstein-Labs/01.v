# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Upstreams::UpdateService, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
  let_it_be(:group) { registry.group }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let(:description) { 'New upstream description' }
  let(:params) { { description: description, metadata_cache_validity_hours: 16 } }

  let(:service) do
    described_class.new(upstream: upstream, current_user: user, params: params)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'denying update to maven virtual registries upstream' do
      it { is_expected.to be_error.and have_attributes(message: 'Unauthorized', reason: :unauthorized) }
    end

    shared_examples 'updating the maven virtual registries upstream' do
      it { is_expected.to be_success.and have_attributes(payload: have_attributes(params)) }
    end

    context 'with different user roles' do
      where(:user_role, :shared_examples_name) do
        :maintainer | 'updating the maven virtual registries upstream'
        :anonymous  | 'denying update to maven virtual registries upstream'
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end

    context 'for admin' do
      let(:user) { build_stubbed(:user, :admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'updating the maven virtual registries upstream'
      end

      context 'when admin mode is disabled' do
        it_behaves_like 'denying update to maven virtual registries upstream'
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it_behaves_like 'denying update to maven virtual registries upstream'
    end

    context 'with invalid parameters' do
      before_all do
        group.add_owner(user)
      end

      context 'when an allowed param fails model validation' do
        let(:params) { { metadata_cache_validity_hours: -1 } }

        it 'returns a persistence error' do
          is_expected.to be_error.and have_attributes(message: ['Metadata cache validity hours must be greater than 0'])
        end
      end

      shared_examples 'returning invalid params error' do
        it 'returns an invalid params error' do
          is_expected.to be_error.and have_attributes(message: 'Invalid parameters provided', reason: :invalid_params)
        end
      end

      context 'when params are empty' do
        let(:params) { {} }

        it_behaves_like 'returning invalid params error'
      end

      context 'when params are nil' do
        let(:params) { nil }

        it_behaves_like 'returning invalid params error'
      end

      context 'when a non allowed param is passed' do
        let(:params) { { foo: 'bar' } }

        it_behaves_like 'returning invalid params error'
      end
    end

    context 'when user is owner of a subgroup of the group that owns registry' do
      let_it_be(:group) { create(:group, parent: group) }

      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'denying update to maven virtual registries upstream'
    end
  end
end
