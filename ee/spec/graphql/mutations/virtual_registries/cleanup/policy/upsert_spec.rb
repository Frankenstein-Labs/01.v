# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Cleanup::Policy::Upsert, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let(:params) do
    {
      full_path: group.full_path,
      enabled: true,
      keep_n_days_after_download: 56,
      cadence: 30,
      notify_on_success: true,
      notify_on_failure: true
    }
  end

  specify { expect(described_class).to require_graphql_authorizations(:admin_virtual_registry) }

  describe '#resolve' do
    subject(:resolve) { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    before do
      allow(VirtualRegistries::Packages::Maven).to receive(:feature_enabled?)
        .and_return(feature_enabled)
    end

    shared_examples 'denying access to virtual registries cleanup policy' do
      it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when group is not present' do
      let(:params) do
        {
          full_path: 'full-path',
          enabled: true
        }
      end

      let(:feature_enabled) { true }

      it_behaves_like 'denying access to virtual registries cleanup policy'
    end

    context 'when virtual registry and cleanup policy are available' do
      let(:feature_enabled) { true }

      context 'when user has permission' do
        before_all do
          group.add_owner(current_user)
        end

        it 'returns virtual_registries_cleanup_policy' do
          result = resolve

          policy = VirtualRegistries::Cleanup::Policy.for_group(group).first
          expect(result).to eq(
            virtual_registries_cleanup_policy: policy,
            errors: []
          )
        end

        it 'creates virtual registries cleanup policy for the group', :aggregate_failures do
          expect { resolve }.to change {
            VirtualRegistries::Cleanup::Policy.for_group(group).count
          }.from(0).to(1)

          policy = VirtualRegistries::Cleanup::Policy.for_group(group).first
          expect(policy).to have_attributes(
            enabled: true,
            keep_n_days_after_download: 56,
            cadence: 30,
            notify_on_success: true,
            notify_on_failure: true
          )
        end

        context 'when virtual registries cleanup policy exists for the given group' do
          let_it_be_with_reload(:policy) { create(:virtual_registries_cleanup_policy, group: group) }

          it 'updates virtual registries cleanup policy' do
            resolve

            expect(policy).to have_attributes(
              enabled: true,
              keep_n_days_after_download: 56,
              cadence: 30,
              notify_on_success: true,
              notify_on_failure: true
            )
          end
        end
      end

      context 'when user has no permission' do
        before_all do
          group.add_guest(current_user)
        end

        it_behaves_like 'denying access to virtual registries cleanup policy'
      end
    end

    context 'when virtual registry is not available' do
      let(:feature_enabled) { false }

      it_behaves_like 'denying access to virtual registries cleanup policy'
    end
  end
end
