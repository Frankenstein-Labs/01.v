# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Minutes, :aggregate_failures, feature_category: :subscription_management do
  include GitlabSubscriptions::InternalApiHelpers

  describe 'POST /namespaces/:id/minutes' do
    let_it_be(:namespace) { create(:namespace) }

    def minutes_path(namespace_id, user = nil, options = {})
      api("/namespaces/#{namespace_id}/minutes", user, **options)
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        post minutes_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace does not exist' do
        it 'returns a 404' do
          pack = { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) }

          post minutes_path(non_existing_record_id), headers: internal_api_headers, params: { packs: [pack] }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when the additional pack does not exist' do
        it 'creates a new additional pack' do
          pack = { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) }

          expect { post minutes_path(namespace.id), headers: internal_api_headers, params: { packs: [pack] } }
            .to change { Ci::Minutes::AdditionalPack.count }.by(1)

          response_pack = json_response.first

          expect(response).to have_gitlab_http_status(:success)
          expect(response_pack['number_of_minutes']).to eq pack[:number_of_minutes]
          expect(response_pack['expires_at']).to eq pack[:expires_at].to_date.to_s
          expect(response_pack['purchase_xid']).to eq pack[:purchase_xid]
          expect(response_pack['namespace_id']).to eq namespace.id
        end
      end

      context 'when the additional pack already exists' do
        it 'does not create a new additional pack and does not update the existing pack' do
          pack = { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) }

          create(
            :ci_minutes_additional_pack,
            purchase_xid: pack[:purchase_xid],
            namespace: namespace,
            number_of_minutes: 20_000
          )

          expect { post minutes_path(namespace.id), headers: internal_api_headers, params: { packs: [pack] } }
            .not_to change { Ci::Minutes::AdditionalPack.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response.first['number_of_minutes']).not_to eq 10_0000
        end
      end

      context 'when submitting multiple packs' do
        context 'when duplicate packs' do
          it 'creates only one new pack' do
            pack = { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) }

            expect { post minutes_path(namespace.id), headers: internal_api_headers, params: { packs: [pack, pack] } }
              .to change { Ci::Minutes::AdditionalPack.count }.by(1)
          end
        end

        context 'when the packs are unique' do
          it 'creates all the packs' do
            packs = [
              { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) },
              { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) },
              { number_of_minutes: 10_000, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(16) }
            ]

            expect { post minutes_path(namespace.id), headers: internal_api_headers, params: { packs: packs } }
              .to change { Ci::Minutes::AdditionalPack.count }.by(3)
          end
        end
      end

      context 'when the additional pack cannot be saved' do
        it 'returns an error' do
          pack = { number_of_minutes: 10, expires_at: 1.year.from_now.to_s, purchase_xid: SecureRandom.hex(55) }

          post minutes_path(namespace.id), headers: internal_api_headers, params: { packs: [pack] }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('Unable to save additional pack')
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:user) { create(:user) }
      let_it_be(:admin_mode) { false }

      let(:namespace_id) { namespace.id }
      let(:minutes_pack) do
        {
          number_of_minutes: 10_000,
          expires_at: (Date.current + 1.year).to_s,
          purchase_xid: SecureRandom.hex(16)
        }
      end

      let(:payload) { { packs: [minutes_pack] } }

      subject(:post_minutes) { post minutes_path(namespace_id, user, admin_mode: admin_mode), params: payload }

      context 'with insufficient access' do
        it 'returns an error' do
          post_minutes

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with admin user' do
        let_it_be(:user) { create(:admin) }
        let_it_be(:admin_mode) { true }

        context 'when the namespace does not exist' do
          let(:namespace_id) { non_existing_record_id }

          it 'returns a 404' do
            post_minutes

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Namespace Not Found')
          end
        end

        context 'when the additional pack does not exist' do
          it 'creates a new additional pack' do
            expect { post_minutes }.to change { Ci::Minutes::AdditionalPack.count }.by(1)

            response_pack = json_response.first

            expect(response).to have_gitlab_http_status(:success)
            expect(response_pack['number_of_minutes']).to eq minutes_pack[:number_of_minutes]
            expect(response_pack['expires_at']).to eq minutes_pack[:expires_at]
            expect(response_pack['purchase_xid']).to eq minutes_pack[:purchase_xid]
            expect(response_pack['namespace_id']).to eq namespace_id
          end
        end

        context 'when the additional pack already exists' do
          before do
            create(
              :ci_minutes_additional_pack,
              purchase_xid: minutes_pack[:purchase_xid],
              namespace: namespace,
              number_of_minutes: 20_000
            )
          end

          it 'does not create a new additional pack and does not update the existing pack' do
            expect { post_minutes }.not_to change { Ci::Minutes::AdditionalPack.count }

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response.first['number_of_minutes']).not_to eq 10_0000
          end

          it_behaves_like 'authorizing granular token permissions', :create_ci_minute do
            let_it_be(:group) { create(:group) }
            let(:boundary_object) { group }
            let(:request) do
              post api("/namespaces/#{group.id}/minutes", personal_access_token: pat), params: payload
            end
          end

          it_behaves_like 'authorizing granular token permissions', :create_ci_minute do
            let_it_be(:user_namespace_owner) { create(:user, :with_namespace) }
            let(:boundary_object) { :user }
            let(:request) do
              post api("/namespaces/#{user_namespace_owner.namespace.id}/minutes", personal_access_token: pat), params: payload
            end
          end
        end

        context 'when submitting multiple packs' do
          context 'when duplicate packs' do
            let(:payload) { { packs: [minutes_pack, minutes_pack] } }

            it 'creates only one new pack' do
              expect { post_minutes }.to change { Ci::Minutes::AdditionalPack.count }.by(1)
            end
          end

          context 'when the packs are unique' do
            let(:payload) do
              {
                packs: [
                  { number_of_minutes: 1_000, expires_at: (Date.current + 1.year).to_s, purchase_xid: SecureRandom.hex(16) },
                  { number_of_minutes: 1_000, expires_at: (Date.current + 1.year).to_s, purchase_xid: SecureRandom.hex(16) },
                  { number_of_minutes: 1_000, expires_at: (Date.current + 1.year).to_s, purchase_xid: SecureRandom.hex(16) }
                ]
              }
            end

            it 'creates all the packs' do
              expect { post_minutes }.to change { Ci::Minutes::AdditionalPack.count }.by(3)
            end
          end
        end

        context 'when the additional pack cannot be saved' do
          it 'returns an error' do
            allow_next_instance_of(Ci::Minutes::AdditionalPack) do |instance|
              allow(instance).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
            end

            post_minutes

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include('Unable to save additional pack')
          end
        end
      end
    end
  end

  describe 'PATCH /namespaces/:id/minutes/move/:target_id' do
    let_it_be(:source_namespace) { create(:group) }
    let_it_be(:target_namespace) { create(:group, owner: source_namespace.owner) }

    def move_path(source_namespace_id, target_namespace_id, user = nil, options = {})
      api("/namespaces/#{source_namespace_id}/minutes/move/#{target_namespace_id}", user, **options)
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        patch move_path(source_namespace.id, target_namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace does not exist' do
        it 'returns a 404' do
          patch move_path(non_existing_record_id, target_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when the target namespace cannot be found' do
        it 'returns a 404' do
          patch move_path(source_namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Target namespace Not Found')
        end
      end

      context 'when the namespace is not a top-level namespace' do
        it 'returns an error' do
          nested_namespace = create(:group, parent: source_namespace)

          patch move_path(nested_namespace.id, target_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('Namespace must be a top-level namespace')
        end
      end

      context 'when the target namespace is not a top-level namespace' do
        it 'returns an error' do
          nested_namespace = create(:group, parent: target_namespace)

          patch move_path(source_namespace.id, nested_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('Target namespace must be a top-level namespace')
        end
      end

      context 'when the transfer is successful' do
        it 'moves the packs and returns an accepted response' do
          create(:ci_minutes_additional_pack, namespace: source_namespace)

          expect { patch move_path(source_namespace.id, target_namespace.id), headers: internal_api_headers }
            .to change { target_namespace.ci_minutes_additional_packs.count }.by(1)

          expect(response).to have_gitlab_http_status(:accepted)
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:child_namespace) { create(:group, :nested) }
      let_it_be(:user) { create(:user) }
      let_it_be(:admin_mode) { false }

      let(:namespace_id) { source_namespace.id }
      let(:target_id) { target_namespace.id }

      subject(:move_packs) { patch move_path(namespace_id, target_id, user, admin_mode: admin_mode) }

      context 'when unauthorized' do
        it 'returns an error' do
          move_packs

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authorized' do
        let_it_be(:user) { create(:admin) }
        let_it_be(:admin_mode) { true }

        context 'when the namespace does not exist' do
          let(:namespace_id) { non_existing_record_id }

          it 'returns a 404' do
            move_packs

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Namespace Not Found')
          end
        end

        context 'when the target namespace cannot be found' do
          let(:target_id) { non_existing_record_id }

          it 'returns a 404' do
            move_packs

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Target namespace Not Found')
          end
        end

        context 'when the namespace is not a top-level namespace' do
          let(:namespace_id) { child_namespace.id }

          it 'returns an error' do
            move_packs

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include('Namespace must be a top-level namespace')
          end
        end

        context 'when the target namespace is not a top-level namespace' do
          let(:target_id) { child_namespace.id }

          it 'returns an error' do
            move_packs

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include('Target namespace must be a top-level namespace')
          end
        end

        context 'when the transfer is successful' do
          let(:target_id) { target_namespace.id }

          before do
            create(:ci_minutes_additional_pack, namespace: source_namespace)
          end

          it 'moves the packs and returns an accepted response' do
            expect { move_packs }.to change { target_namespace.ci_minutes_additional_packs.count }.by(1)

            expect(response).to have_gitlab_http_status(:accepted)
          end

          it_behaves_like 'authorizing granular token permissions', :transfer_ci_minute do
            let(:boundary_object) { source_namespace }
            let(:request) do
              patch api("/namespaces/#{namespace_id}/minutes/move/#{target_id}", personal_access_token: pat)
            end
          end

          it_behaves_like 'authorizing granular token permissions', :transfer_ci_minute do
            let_it_be(:user_namespace_owner) { create(:user, :with_namespace) }
            let(:boundary_object) { :user }
            let(:request) do
              patch api("/namespaces/#{user_namespace_owner.namespace.id}/minutes/move/#{target_namespace.id}",
                personal_access_token: pat)
            end
          end
        end
      end
    end
  end
end
