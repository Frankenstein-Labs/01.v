# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Namespaces::Provision, :aggregate_failures, :api, feature_category: :plan_provisioning do
  include GitlabSubscriptions::InternalApiHelpers

  let_it_be(:ultimate_plan) { create(:ultimate_plan) }
  let_it_be_with_reload(:namespace) { create(:group) }
  let_it_be(:start_date) { Date.current.to_s }
  let_it_be(:end_date) { 1.year.from_now.to_date.to_s }

  let(:provision_path) { internal_api("namespaces/#{namespace_id}/provision") }
  let(:namespace_id) { namespace.id }
  let(:new_subscription) { false }
  let(:contract_overages_allowed) { false }

  let(:params) do
    {
      provision: {
        base_product: {
          plan_code: 'ultimate',
          seats: 30,
          start_date: start_date,
          end_date: end_date,
          max_seats_used: 10,
          auto_renew: true,
          trial: false,
          trial_starts_on: nil,
          trial_ends_on: nil,
          contract_overages_allowed: contract_overages_allowed
        },
        storage: {
          additional_purchased_storage_size: 100,
          additional_purchased_storage_ends_on: end_date
        },
        compute_minutes: {
          extra_shared_runners_minutes_limit: 90,
          shared_runners_minutes_limit: 100
        },
        add_on_purchases: {
          duo_core: [{
            started_on: start_date,
            expires_on: end_date,
            purchase_xid: 'A-S00001',
            quantity: 30,
            trial: false,
            new_subscription: new_subscription
          }],
          duo_pro: [{
            started_on: start_date,
            expires_on: end_date,
            purchase_xid: 'A-S00001',
            quantity: 1,
            trial: false
          }],
          duo_enterprise: [{
            started_on: start_date,
            expires_on: end_date,
            purchase_xid: 'A-S00001',
            quantity: 1,
            trial: false
          }],
          gitlab_credits: [{
            started_on: start_date,
            expires_on: end_date,
            purchase_xid: 'A-S00001',
            quantity: 1,
            trial: false
          }],
          product_analytics: [{
            started_on: start_date,
            expires_on: end_date,
            purchase_xid: 'A-S00002',
            quantity: 1,
            trial: false
          }]
        }
      }
    }
  end

  describe 'POST /internal/gitlab_subscriptions/namespaces/:id/provision' do
    subject(:result) do
      post provision_path, params: params
      response
    end

    it { is_expected.to have_gitlab_http_status(:unauthorized) }

    context 'when authenticated as the subscription portal' do
      subject(:result) do
        post provision_path, headers: internal_api_headers, params: params
        response
      end

      before do
        stub_internal_api_authentication
      end

      it 'does the complete provision of the namespace' do
        expect(result).to have_gitlab_http_status(:ok)

        expect(namespace.reload.gitlab_subscription.plan_name).to eq('ultimate')
        expect(namespace.gitlab_subscription).to have_attributes(
          seats: 30,
          start_date: Date.parse(start_date),
          end_date: Date.parse(end_date),
          max_seats_used: 10,
          auto_renew: true,
          trial: false,
          trial_starts_on: nil,
          trial_ends_on: nil,
          contract_overages_allowed: false
        )

        expect(namespace.additional_purchased_storage_size).to eq(100)
        expect(namespace.additional_purchased_storage_ends_on).to eq(Date.parse(end_date))

        expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
        expect(namespace.shared_runners_minutes_limit).to eq(100)

        expect(namespace.subscription_add_on_purchases.uniq_add_on_names)
          .to match_array(%w[duo_core duo_enterprise gitlab_credits product_analytics])
        # duo_enterprise gets priority over duo_pro with bulk_sync
        expect(namespace.subscription_add_on_purchases.for_duo_enterprise.last).to have_attributes(
          started_at: Date.parse(start_date),
          expires_on: Date.parse(end_date),
          purchase_xid: 'A-S00001',
          quantity: 1,
          trial: false
        )
      end

      context 'when Duo Core params new_subscription flag is true' do
        let(:new_subscription) { true }

        it_behaves_like 'enables DuoCore automatically only if customer has not chosen DuoCore setting for namespace'
      end

      context 'when Duo Core params new_subscription flag is false' do
        let(:new_subscription) { false }

        it_behaves_like 'does not change namespace Duo Core features setting'
      end

      context 'when contract_overages_allowed is true' do
        let(:contract_overages_allowed) { true }

        it 'passes the value' do
          expect(result).to have_gitlab_http_status(:ok)
          expect(namespace.gitlab_subscription).to be_contract_overages_allowed
        end
      end

      context 'when contract_overages_allowed is false' do
        let(:contract_overages_allowed) { false }

        it 'passes the value' do
          expect(result).to have_gitlab_http_status(:ok)
          expect(namespace.gitlab_subscription).not_to be_contract_overages_allowed
        end
      end

      context 'when contract_overages_allowed attribute does not exist' do
        before do
          params[:provision][:base_product].delete(:contract_overages_allowed)
        end

        it 'uses the default value' do
          expect(result).to have_gitlab_http_status(:ok)
          expect(namespace.gitlab_subscription).to be_contract_overages_allowed
        end
      end

      context 'when only single resource params is sent' do
        context 'with Duo Pro' do
          let(:params) do
            {
              provision: {
                add_on_purchases: {
                  duo_pro: [{
                    started_on: start_date,
                    expires_on: end_date,
                    purchase_xid: 'A-S00001',
                    quantity: 1,
                    trial: false
                  }]
                }
              }
            }
          end

          it 'provisions only single resource: Duo Pro Add-on purchase' do
            expect(result).to have_gitlab_http_status(:ok)

            expect(namespace.reload.extra_shared_runners_minutes_limit).to be_nil

            expect(namespace.gitlab_subscription).to be_nil
            expect(namespace.additional_purchased_storage_size).to eq(0)

            expect(namespace.subscription_add_on_purchases.uniq_add_on_names).to match_array(%w[code_suggestions])
            expect(namespace.subscription_add_on_purchases.for_gitlab_duo_pro.last).to have_attributes(
              started_at: Date.parse(start_date),
              expires_on: Date.parse(end_date),
              purchase_xid: 'A-S00001',
              quantity: 1,
              trial: false
            )
          end
        end

        context 'with Duo Core' do
          let(:params) do
            {
              provision: {
                add_on_purchases: {
                  duo_core: [{
                    started_on: start_date,
                    expires_on: end_date,
                    purchase_xid: 'A-S00001',
                    quantity: 10,
                    trial: false
                  }]
                }
              }
            }
          end

          it 'provisions only single resource: Duo Core Add-on purchase' do
            expect(result).to have_gitlab_http_status(:ok)

            expect(namespace.reload.extra_shared_runners_minutes_limit).to be_nil

            expect(namespace.gitlab_subscription).to be_nil
            expect(namespace.additional_purchased_storage_size).to eq(0)

            duo_core_add_on_id = GitlabSubscriptions::AddOn.duo_core.pick(:id)
            duo_core_add_on_purchase = namespace.subscription_add_on_purchases
              .where(subscription_add_on_id: duo_core_add_on_id)
              .first

            expect(namespace.subscription_add_on_purchases.uniq_add_on_names).to match_array(%w[duo_core])
            expect(duo_core_add_on_purchase).to have_attributes(
              started_at: Date.parse(start_date),
              expires_on: Date.parse(end_date),
              purchase_xid: 'A-S00001',
              quantity: 10,
              trial: false
            )
          end
        end
      end

      context 'when non existing namespace ID is given' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when a project namespace ID is given' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: group, name: group.name, path: group.path) }
        let(:namespace_id) { project.project_namespace.id }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when the namespace ID is not a root namespace' do
        let(:namespace_id) { create(:group, :nested).id }

        it { is_expected.to have_gitlab_http_status(:bad_request) }
      end

      context 'when provision params are missing' do
        let(:params) { {} }

        it { is_expected.to have_gitlab_http_status(:bad_request) }
      end

      context 'when the provision params are invalid' do
        before do
          params[:provision][:base_product][:seats] = nil
        end

        it 'returns unprocessable_entity status, but provisions other resources with correct attributes' do
          expect(result).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to match(/seats can't be blank/)

          expect(namespace.reload.gitlab_subscription).to be_nil

          expect(namespace.additional_purchased_storage_size).to eq(100)
          expect(namespace.additional_purchased_storage_ends_on).to eq(Date.parse(end_date))

          expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
          expect(namespace.shared_runners_minutes_limit).to eq(100)

          expect(namespace.subscription_add_on_purchases.uniq_add_on_names)
            .to match_array(%w[duo_core duo_enterprise gitlab_credits product_analytics])
        end
      end

      context 'when an unknown add-on type is provided' do
        let(:params) do
          {
            provision: {
              add_on_purchases: {
                future_feature: [{
                  started_on: start_date,
                  expires_on: end_date,
                  purchase_xid: 'A-S00001',
                  quantity: 1,
                  trial: false
                }]
              }
            }
          }
        end

        it 'accepts the request at the API level, validation errors occur at service level' do
          expect(result).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq("'future_feature' is not a valid name")
        end
      end

      context 'when both valid and invalid add-ons are provided' do
        let(:params) do
          {
            provision: {
              add_on_purchases: {
                duo_core: [{
                  started_on: start_date,
                  expires_on: end_date,
                  purchase_xid: 'A-S00001',
                  quantity: 5,
                  trial: false
                }],
                future_feature: [{
                  started_on: start_date,
                  expires_on: end_date,
                  purchase_xid: 'A-S00002',
                  quantity: 1,
                  trial: false
                }]
              }
            }
          }
        end

        it 'provisions valid add-ons while reporting errors for invalid ones' do
          expect(result).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq("'future_feature' is not a valid name")
          expect(GitlabSubscriptions::AddOnPurchase.by_namespace(namespace).by_add_on_name(:duo_core)).to exist
        end
      end
    end
  end
end
