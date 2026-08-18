# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Settings::CreateOrUpdateService, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:current_user) { create(:user) }
  let(:params) { { enabled: true } }

  shared_examples 'denying access to virtual registries settings' do
    it 'returns an error' do
      expect(service).to have_attributes(
        message: 'Unauthorized',
        status: :error,
        reason: :unauthorized
      )
    end
  end

  shared_examples 'creating the virtual registries setting' do
    it 'creates the setting and returns a success response with payload', :aggregate_failures do
      expect { service }.to change {
        VirtualRegistries::Setting.where(group: group).count
      }.from(0).to(1)

      is_expected.to be_success.and have_attributes(
        payload: { virtual_registries_setting: have_attributes(enabled: true) }
      )
    end
  end

  describe '#execute' do
    subject(:service) { described_class.new(group: group, current_user: current_user, params: params).execute }

    context 'with different user roles' do
      where(:user_role, :shared_examples_name) do
        :owner      | 'creating the virtual registries setting'
        :maintainer | 'denying access to virtual registries settings'
        :developer  | 'denying access to virtual registries settings'
        :reporter   | 'denying access to virtual registries settings'
        :guest      | 'denying access to virtual registries settings'
        :anonymous  | 'denying access to virtual registries settings'
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", current_user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end

    context 'for admin' do
      let(:current_user) { build_stubbed(:user, :admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'creating the virtual registries setting'
      end

      context 'when admin mode is disabled' do
        it_behaves_like 'denying access to virtual registries settings'
      end
    end

    context 'when a virtual registries setting exists' do
      let_it_be_with_reload(:setting) { create(:virtual_registries_setting, :disabled, group: group) }

      before_all do
        group.add_owner(current_user)
      end

      it 'updates the existing setting and returns success', :aggregate_failures do
        expect { service }.to not_change {
          VirtualRegistries::Setting.where(group: group).count
        }

        is_expected.to be_success.and have_attributes(
          payload: { virtual_registries_setting: have_attributes(enabled: true) }
        )
      end
    end

    context 'with invalid parameters' do
      before_all do
        group.add_owner(current_user)
      end

      context 'when enabled is nil' do
        let(:params) { { enabled: nil } }

        it 'returns a persistence error' do
          expect(service).to have_attributes(
            message: 'Validation failed: Enabled is not included in the list',
            status: :error,
            reason: :persistence_error
          )
        end
      end

      context 'when params are empty' do
        let(:params) { {} }

        it 'returns an invalid params error' do
          expect(service).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
        end
      end

      context 'when params are nil' do
        let(:params) { nil }

        it 'returns an invalid params error' do
          expect(service).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
        end
      end

      context 'when a non allowed param is passed' do
        let(:params) { { foo: 'bar' } }

        it 'returns an invalid params error' do
          expect(service).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
        end
      end
    end

    context 'when group is a subgroup' do
      let_it_be(:group) { create(:group, parent: group) }

      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'denying access to virtual registries settings'
    end
  end
end
