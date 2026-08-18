# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::Policies::CreateOrUpdateService, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:current_user) { create(:user) }
  let(:params) do
    {
      enabled: true,
      keep_n_days_after_download: 30,
      cadence: 14,
      notify_on_success: true,
      notify_on_failure: false
    }
  end

  describe '#execute' do
    let(:service) { described_class.new(group: group, current_user: current_user, params: params) }

    subject(:execute) { service.execute }

    shared_examples 'denying access to virtual registries cleanup policy' do
      it 'returns an error' do
        expect(execute).to have_attributes(
          message: 'Unauthorized',
          status: :error,
          reason: :unauthorized
        )
      end
    end

    shared_examples 'creating virtual registries cleanup policy' do
      it_behaves_like 'handle errors'

      it 'creates the policy and returns a success response with payload', :aggregate_failures do
        expect { execute }.to change {
          VirtualRegistries::Cleanup::Policy.for_group(group).count
        }.by(1)

        is_expected.to be_success.and have_attributes(
          payload: { virtual_registries_cleanup_policy: have_attributes(**params) }
        )
      end

      context 'when param is not given' do
        where(:field_name, :default_value) do
          :enabled                    | false
          :keep_n_days_after_download | 30
          :cadence                    | 7
          :notify_on_success          | false
          :notify_on_failure          | false
        end

        with_them do
          let(:params) { super().except(field_name) }

          subject(:cleanup_policy) { execute.payload[:virtual_registries_cleanup_policy] }

          it { is_expected.to have_attributes(field_name => default_value) }
        end
      end

      context 'when params are nil' do
        let(:params) { nil }
        let(:expected_attrs) do
          {
            enabled: false,
            keep_n_days_after_download: 30,
            cadence: 7,
            notify_on_success: false,
            notify_on_failure: false
          }
        end

        subject(:cleanup_policy) { execute.payload[:virtual_registries_cleanup_policy] }

        it { is_expected.to have_attributes(expected_attrs) }
      end
    end

    shared_examples 'handle errors' do
      context 'when a non allowed param is passed' do
        let(:params) { { foo: 'bar' } }

        it 'returns an invalid params error' do
          expect(execute).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
        end
      end

      context 'when group is a subgroup' do
        let(:group) { create(:group, parent: super(), owners: [current_user]) }

        it_behaves_like 'denying access to virtual registries cleanup policy'
      end
    end

    context 'with different user roles' do
      where(:user_role, :shared_examples_name) do
        :owner      | 'creating virtual registries cleanup policy'
        :maintainer | 'denying access to virtual registries cleanup policy'
        :developer  | 'denying access to virtual registries cleanup policy'
        :reporter   | 'denying access to virtual registries cleanup policy'
        :guest      | 'denying access to virtual registries cleanup policy'
        :anonymous  | 'denying access to virtual registries cleanup policy'
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", current_user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end

    context 'for admin' do
      let(:current_user) { build_stubbed(:admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'creating virtual registries cleanup policy'
      end

      context 'when admin mode is disabled' do
        it_behaves_like 'denying access to virtual registries cleanup policy'
      end
    end

    context 'when a virtual registries cleanup policy exists' do
      let_it_be_with_reload(:policy) { create(:virtual_registries_cleanup_policy, group: group) }

      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'handle errors'

      it 'updates the existing policy and returns success', :aggregate_failures do
        expect { execute }.to not_change {
          VirtualRegistries::Cleanup::Policy.for_group(group).count
        }

        is_expected.to be_success.and have_attributes(
          payload: { virtual_registries_cleanup_policy: have_attributes(enabled: true) }
        )
      end

      context 'when params are nil' do
        let(:params) { nil }

        it 'returns an invalid params error' do
          expect(execute).to have_attributes(
            message: 'Invalid parameters provided',
            status: :error,
            reason: :invalid_params
          )
        end
      end

      context 'when update fails' do
        let(:params) { { cadence: 5 } }

        it 'returns an persistence_error' do
          expect(execute).to have_attributes(
            message: 'Validation failed: Cadence is not included in the list',
            status: :error,
            reason: :persistence_error
          )
        end
      end

      context 'when current_user is nill' do
        let(:current_user) { nil }

        it_behaves_like 'denying access to virtual registries cleanup policy'
      end
    end
  end
end
