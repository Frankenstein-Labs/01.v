# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting an admin-locked GitLab Duo availability override', feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }

  let(:current_user) { admin }
  let(:availability) { 'NEVER_ON' }
  let(:group_gid) { group.to_global_id.to_s }

  let(:mutation_params) do
    {
      groupId: group_gid,
      availability: availability
    }
  end

  let(:mutation_name) { :admin_set_duo_availability }
  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  before_all do
    group.add_owner(owner)
  end

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the user is not an admin' do
      let(:current_user) { owner }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when the user is an admin', :enable_admin_mode do
      it 'sets the admin-locked override and returns the resolved availability' do
        request

        result = graphql_mutation_response(mutation_name)

        expect(result['errors']).to eq([])
        expect(result['availability']).to eq('NEVER_ON')
        expect(result['adminLocked']).to be(true)

        setting = group.namespace_settings.reload
        expect(setting.admin_locked_duo_features_enabled).to be(true)
        expect(setting.duo_features_enabled).to be(false)
        expect(setting.lock_duo_features_enabled).to be(true)
      end

      context 'with a non-locking availability value' do
        context 'when defaulting to on' do
          let(:availability) { 'DEFAULT_ON' }

          it 'applies the availability without admin-locking the group', :aggregate_failures do
            request

            result = graphql_mutation_response(mutation_name)

            expect(result['errors']).to eq([])
            expect(result['availability']).to eq('DEFAULT_ON')
            expect(result['adminLocked']).to be(false)

            expect(group.namespace_settings.reload.admin_locked_duo_features_enabled).to be(false)
          end
        end

        context 'when defaulting to off' do
          let(:availability) { 'DEFAULT_OFF' }

          it 'applies the availability without admin-locking the group', :aggregate_failures do
            request

            result = graphql_mutation_response(mutation_name)

            expect(result['errors']).to eq([])
            expect(result['availability']).to eq('DEFAULT_OFF')
            expect(result['adminLocked']).to be(false)

            expect(group.namespace_settings.reload.admin_locked_duo_features_enabled).to be(false)
          end
        end
      end

      context 'with an invalid availability value' do
        it 'returns a validation error from the enum' do
          mutation_params[:availability] = 'NOT_A_STATE'

          request

          expect(graphql_errors).to be_present
        end
      end

      context 'when a parent group is already admin-locked' do
        let_it_be(:sub_group, freeze: false) { create(:group, parent: group) }

        let(:group_gid) { sub_group.to_global_id.to_s }

        before do
          group.namespace_settings.reload.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            admin_locked_duo_features_enabled: true
          )
        end

        it 'returns an error and does not lock the child group' do
          request

          result = graphql_mutation_response(mutation_name)

          expect(result['errors']).to be_present
          expect(sub_group.namespace_settings.reload.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'when a subgroup is already admin-locked' do
        let_it_be(:sub_group, freeze: false) { create(:group, parent: group) }

        let(:mutation) do
          graphql_mutation(mutation_name, mutation_params) do
            <<~FIELDS
              errors
              availability
              adminLocked
              affectedAdminLockedDescendants {
                nodes { fullPath }
              }
            FIELDS
          end
        end

        before do
          sub_group.namespace_settings.reload.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            admin_locked_duo_features_enabled: true
          )
        end

        it 'returns the affected descendants and does not lock the group', :aggregate_failures do
          request

          result = graphql_mutation_response(mutation_name)

          expect(result['errors']).to be_present
          expect(result['availability']).to be_nil
          expect(result['adminLocked']).to be_nil
          expect(result['affectedAdminLockedDescendants']['nodes'])
            .to contain_exactly(a_hash_including('fullPath' => sub_group.full_path))
          expect(group.namespace_settings.reload.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'when the service returns a generic error' do
        let(:error_message) { 'Something went wrong.' }

        before do
          allow_next_instance_of(::Ai::DuoSettings::SetNamespaceOverrideService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
          end
        end

        it 'returns the error message with null availability fields', :aggregate_failures do
          request

          result = graphql_mutation_response(mutation_name)

          expect(result['errors']).to eq([error_message])
          expect(result['availability']).to be_nil
          expect(result['adminLocked']).to be_nil
        end
      end
    end
  end
end
