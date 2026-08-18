# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::UpdateUpstreamService, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:registry) { create(:virtual_registries_container_registry) }
  let_it_be(:group) { registry.group }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:description) { 'New upstream description' }
  let(:params) { { description: description } }

  let!(:service) do
    described_class.new(upstream: upstream, current_user: user, params: params)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'denying update to container virtual registries upstream' do
      it 'returns an error' do
        expect(execute).to have_attributes(
          message: 'Unauthorized',
          status: :error,
          reason: :unauthorized
        )
      end
    end

    shared_examples 'updating the container virtual registries upstream' do
      it 'updates upstream attributes' do
        execute

        expect(upstream).to have_attributes(params)
      end

      it 'returns a success response with payload' do
        is_expected.to be_success.and have_attributes(payload: upstream)
      end
    end

    context 'with different user roles' do
      where(:user_role, :shared_examples_name) do
        :maintainer | 'updating the container virtual registries upstream'
        :anonymous  | 'denying update to container virtual registries upstream'
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
        it_behaves_like 'updating the container virtual registries upstream'
      end

      context 'when admin mode is disabled' do
        it_behaves_like 'denying update to container virtual registries upstream'
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it_behaves_like 'denying update to container virtual registries upstream'
    end

    context 'with invalid parameters' do
      before_all do
        group.add_owner(user)
      end

      context 'when enabled is nil' do
        let(:params) { { cache_validity_hours: -1 } }

        it 'returns a persistence error' do
          expect(execute).to have_attributes(
            message: 'Validation failed: Cache validity hours must be greater than or equal to 0',
            status: :error,
            reason: :persistence_error
          )
        end
      end

      shared_examples 'returning invalid params error' do
        it 'returns an invalid params error' do
          expect(execute).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
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

      it_behaves_like 'denying update to container virtual registries upstream'
    end
  end
end
