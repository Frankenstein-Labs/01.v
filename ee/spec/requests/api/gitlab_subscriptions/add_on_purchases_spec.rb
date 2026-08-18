# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GitlabSubscriptions::AddOnPurchases, :aggregate_failures, feature_category: :plan_provisioning do
  include GitlabSubscriptions::InternalApiHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

  def add_on_purchase_path(namespace_id, add_on_name, user = nil, options = {})
    api("/namespaces/#{namespace_id}/subscription_add_on_purchase/#{add_on_name}", user, **options)
  end

  describe 'POST /namespaces/:id/subscription_add_on_purchase/:add_on_name' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        post add_on_purchase_path(namespace.id, add_on.name)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      let(:valid_params) do
        { quantity: 10, started_on: Date.current, expires_on: 1.year.from_now, purchase_xid: 'A-123456' }
      end

      context 'when the namespace cannot be found' do
        it 'returns a not_found error' do
          post add_on_purchase_path(non_existing_record_id, add_on.name), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on cannot be found' do
        it 'returns a not_found error' do
          post add_on_purchase_path(namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase does not exist' do
        it 'creates a new add-on purchase', :freeze_time do
          expect do
            post add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: valid_params
          end.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq(
            'namespace_id' => namespace.id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'quantity' => valid_params[:quantity],
            'started_on' => valid_params[:started_on].to_s,
            'expires_on' => valid_params[:expires_on].to_date.to_s,
            'purchase_xid' => valid_params[:purchase_xid],
            'trial' => false
          )
        end
      end

      context 'when the add-on purchase cannot be saved' do
        it 'returns an error' do
          params = valid_params.merge(quantity: 0)

          expect { post add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: params }
            .not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('"quantity":["must be greater than or equal to 1"]')
        end
      end

      context 'when the add-on purchase already exists' do
        it 'does not create a new add-on purchase and does not update the existing one' do
          create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on)

          expect do
            post add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: valid_params
          end.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include(
            "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} already exists"
          )
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:purchase_xid) { 'S-A00000001' }
      let(:namespace_id) { namespace.id }
      let(:add_on_name) { add_on.name }

      let(:params) do
        {
          quantity: 10,
          started_on: Date.current.to_s,
          expires_on: (Date.current + 1.year).to_s,
          purchase_xid: purchase_xid
        }
      end

      it_behaves_like 'authorizing granular token permissions', :create_add_on_purchase do
        let(:boundary_object) { :instance }
        let(:user) { admin }
        let(:request) do
          post add_on_purchase_path(namespace.id, add_on.name, nil, personal_access_token: pat), params: params
        end
      end

      context 'with a non-admin user' do
        it 'returns :forbidden' do
          post add_on_purchase_path(namespace_id, add_on_name, create(:user), admin_mode: false), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with admin user' do
        subject(:post_add_on_purchase) do
          post add_on_purchase_path(namespace_id, add_on_name, admin, admin_mode: true), params: params

          response
        end

        context 'when the namespace cannot be found' do
          let(:namespace_id) { non_existing_record_id }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on cannot be found' do
          let(:add_on_name) { 'non-existing-add-on' }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on purchase does not exist' do
          it 'creates a new add-on purchase' do
            expect { post_add_on_purchase }.to change { GitlabSubscriptions::AddOnPurchase.count }

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response['namespace_id']).to eq(namespace_id)
            expect(json_response['namespace_name']).to eq(namespace.name)
            expect(json_response['add_on']).to eq(add_on.name.titleize)
            expect(json_response['quantity']).to eq(params[:quantity])
            expect(json_response['started_on']).to eq(params[:started_on])
            expect(json_response['expires_on']).to eq(params[:expires_on])
            expect(json_response['purchase_xid']).to eq(params[:purchase_xid])
          end

          context 'when product_analytics_billing flag is disabled' do
            before do
              stub_feature_flags(product_analytics_billing: false)
            end

            context 'when the add-on is product_analytics' do
              let(:add_on_name) { 'product_analytics' }

              it 'does not create a new add-on purchase' do
                expect { post_add_on_purchase }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
              end
            end

            context 'when the add-on is code_suggestions' do
              let(:add_on_name) { 'code_suggestions' }

              it 'creates a new add-on purchase' do
                expect { post_add_on_purchase }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
              end
            end
          end

          context 'when product_analytics_billing flag is enabled' do
            before do
              stub_feature_flags(product_analytics_billing: namespace)
            end

            context 'when the add-on is product_analytics' do
              let(:add_on_name) { 'product_analytics' }

              it 'creates a new add-on purchase' do
                expect { post_add_on_purchase }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
              end
            end

            context 'when the add-on is code_suggestions' do
              let(:add_on_name) { 'code_suggestions' }

              it 'creates a new add-on purchase' do
                expect { post_add_on_purchase }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
              end
            end
          end

          context 'when the add-on purchase cannot be saved' do
            let(:params) { super().merge(quantity: 0) }

            it 'returns an error' do
              post_add_on_purchase

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to include('"quantity":["must be greater than or equal to 1"]')
              expect(json_response['quantity']).not_to eq(10)
            end
          end
        end

        context 'when the add-on purchase already exists' do
          before do
            create(
              :gitlab_subscription_add_on_purchase,
              namespace: namespace,
              add_on: add_on,
              quantity: 5,
              purchase_xid: purchase_xid
            )
          end

          it 'does not create a new add-on purchase and does not update the existing one' do
            expect { post_add_on_purchase }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include(
              "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} already exists, " \
              'update the existing record'
            )
            expect(json_response['quantity']).not_to eq(10)
          end
        end
      end
    end
  end

  describe 'GET /namespaces/:id/subscription_add_on_purchase/:add_on_name' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        get add_on_purchase_path(namespace.id, add_on.name)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns a not_found error' do
          get add_on_purchase_path(non_existing_record_id, add_on.name), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on cannot be found' do
        it 'returns a not_found error' do
          get add_on_purchase_path(namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase does not exist' do
        it 'returns a not_found error' do
          get add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase exists' do
        it 'returns the found add-on purchase' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on)

          get add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq(
            'namespace_id' => namespace.id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'quantity' => add_on_purchase.quantity,
            'started_on' => add_on_purchase.started_at.to_s,
            'expires_on' => add_on_purchase.expires_on.to_s,
            'purchase_xid' => add_on_purchase.purchase_xid,
            'trial' => add_on_purchase.trial
          )
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:purchase_xid) { 'S-A00000001' }
      let(:namespace_id) { namespace.id }
      let(:add_on_name) { add_on.name }

      subject(:get_add_on_purchase) do
        get add_on_purchase_path(namespace.id, add_on.name, user, admin_mode: admin_mode)

        response
      end

      it_behaves_like 'authorizing granular token permissions', :read_add_on_purchase do
        let(:boundary_object) { :instance }
        let(:user) { admin }

        before do
          create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on, purchase_xid: purchase_xid)
        end

        let(:request) { get add_on_purchase_path(namespace.id, add_on.name, nil, personal_access_token: pat) }
      end

      context 'with a non-admin user' do
        let_it_be(:admin_mode) { false }
        let_it_be(:user) { create(:user) }

        it 'returns :forbidden' do
          get_add_on_purchase

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with admin user' do
        let_it_be(:admin_mode) { true }
        let_it_be(:user) { admin }

        context 'when the namespace cannot be found' do
          let(:namespace_id) { non_existing_record_id }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on cannot be found' do
          let(:add_on_name) { 'non-existing-add-on' }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on purchase does not exist' do
          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on purchase exists' do
          it 'returns the found add-on purchase' do
            add_on_purchase = create(
              :gitlab_subscription_add_on_purchase,
              namespace: namespace,
              add_on: add_on,
              quantity: 5,
              purchase_xid: purchase_xid
            )

            get_add_on_purchase

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response).to eq(
              'namespace_id' => namespace_id,
              'namespace_name' => namespace.name,
              'add_on' => add_on.name.titleize,
              'quantity' => add_on_purchase.quantity,
              'started_on' => add_on_purchase.started_at.to_s,
              'expires_on' => add_on_purchase.expires_on.to_s,
              'purchase_xid' => add_on_purchase.purchase_xid,
              'trial' => add_on_purchase.trial
            )
          end
        end
      end
    end
  end

  describe 'PUT /namespaces/:id/subscription_add_on_purchase/:add_on_name' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        put add_on_purchase_path(namespace.id, add_on.name)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns a not_found error' do
          put add_on_purchase_path(non_existing_record_id, add_on.name), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on cannot be found' do
        it 'returns a not_found error' do
          put add_on_purchase_path(namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase does not exist' do
        it 'returns an error' do
          params = { started_on: Date.current, expires_on: 1.year.from_now }

          put add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include(
            "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} does not exist"
          )
        end
      end

      context 'when the add-on purchase exists' do
        let_it_be(:purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }

        it 'updates the found add-on purchase', :freeze_time do
          params = {
            quantity: 10,
            started_on: Date.current,
            expires_on: 1.year.from_now,
            purchase_xid: 'A-123',
            trial: true
          }

          put add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq(
            'namespace_id' => namespace.id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'quantity' => 10,
            'started_on' => Date.current.to_s,
            'expires_on' => 1.year.from_now.to_date.to_s,
            'purchase_xid' => 'A-123',
            'trial' => true
          )
        end

        context 'when the add-on purchase cannot be saved' do
          it 'returns an error' do
            params = { quantity: 0, started_on: Date.current, expires_on: 1.year.from_now }

            put add_on_purchase_path(namespace.id, add_on.name), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include('"quantity":["must be greater than or equal to 1"]')
          end
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:purchase_xid) { 'S-A00000001' }
      let(:namespace_id) { namespace.id }
      let(:add_on_name) { add_on.name }

      let(:params) do
        {
          quantity: 10,
          started_on: Date.current.to_s,
          expires_on: (Date.current + 1.year).to_s,
          purchase_xid: purchase_xid,
          trial: true
        }
      end

      subject(:put_add_on_purchase) do
        put add_on_purchase_path(namespace_id, add_on_name, user, admin_mode: admin_mode), params: params
      end

      it_behaves_like 'authorizing granular token permissions', :update_add_on_purchase do
        let(:boundary_object) { :instance }
        let(:user) { admin }

        before do
          create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on, purchase_xid: purchase_xid)
        end

        let(:request) do
          put add_on_purchase_path(namespace.id, add_on.name, nil, personal_access_token: pat), params: params
        end
      end

      context 'with a non-admin user' do
        let_it_be(:admin_mode) { false }
        let_it_be(:user) { create(:user) }

        it 'returns :forbidden' do
          put_add_on_purchase

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with admin user' do
        let_it_be(:admin_mode) { true }
        let_it_be(:user) { admin }

        context 'when the namespace to update cannot be found' do
          let(:namespace_id) { non_existing_record_id }

          it 'returns a not_found error' do
            put_add_on_purchase

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the add on to update cannot be found' do
          let(:add_on_name) { non_existing_record_id }

          it 'returns a not_found error' do
            put_add_on_purchase

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the add-on purchase exists' do
          let_it_be(:expires_on) { Date.current + 6.months }
          let_it_be(:started_at) { Date.current + 1.week }
          let_it_be_with_reload(:add_on_purchase) do
            create(
              :gitlab_subscription_add_on_purchase,
              namespace: namespace,
              add_on: add_on,
              quantity: 5,
              started_at: started_at,
              expires_on: expires_on,
              purchase_xid: purchase_xid
            )
          end

          it 'updates the found add-on purchase' do
            expect do
              put_add_on_purchase
              add_on_purchase.reload
            end.to change { add_on_purchase.quantity }.from(5).to(10)
              .and change { add_on_purchase.expires_on }.from(expires_on).to(params[:expires_on].to_date)
              .and change { add_on_purchase.trial }.from(false).to(true)

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response).to eq(
              'namespace_id' => namespace_id,
              'namespace_name' => namespace.name,
              'add_on' => add_on.name.titleize,
              'quantity' => params[:quantity],
              'started_on' => params[:started_on],
              'expires_on' => params[:expires_on],
              'purchase_xid' => params[:purchase_xid],
              'trial' => params[:trial]
            )
          end

          context 'with only required params' do
            let(:params) do
              {
                expires_on: (Date.current + 1.year).to_s,
                started_on: (Date.current + 1.week).to_s
              }
            end

            it 'updates the add-on purchase' do
              expect do
                put_add_on_purchase
                add_on_purchase.reload
              end.to change { add_on_purchase.expires_on }.from(expires_on).to(params[:expires_on].to_date)
                .and not_change { add_on_purchase.quantity }

              expect(response).to have_gitlab_http_status(:success)
              expect(json_response).to eq(
                'namespace_id' => namespace_id,
                'namespace_name' => namespace.name,
                'add_on' => add_on.name.titleize,
                'quantity' => add_on_purchase.quantity,
                'started_on' => params[:started_on],
                'expires_on' => params[:expires_on],
                'purchase_xid' => add_on_purchase.purchase_xid,
                'trial' => add_on_purchase.trial
              )
            end
          end

          context 'when the add-on purchase cannot be saved' do
            let(:params) { super().merge(quantity: 0) }

            it 'returns an error' do
              put_add_on_purchase

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.body).to include('"quantity":["must be greater than or equal to 1"]')
            end
          end
        end

        context 'when the add-on purchase does not exist' do
          it 'returns an error' do
            put_add_on_purchase

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include(
              "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} does not exist, " \
              'create a new record instead'
            )
          end
        end
      end
    end
  end
end
