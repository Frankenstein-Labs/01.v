# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::GroupsController, feature_category: :subscription_management do
  let_it_be(:user) { create(:user) }

  describe 'GET #new' do
    context 'with an unauthenticated user' do
      subject(:get_new) do
        get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id' }
        response
      end

      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      subject(:get_new) do
        get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id' }
        response
      end

      before do
        sign_in(user)
      end

      context 'when plan_type is provided' do
        subject(:get_new) do
          get new_gitlab_subscriptions_group_path,
            params: { plan_type: 'gitlab_credits', product_name: 'GitLab Credits - Monthly Committed Pool' }
          response
        end

        it { is_expected.to render_template 'layouts/minimal' }
        it { is_expected.to render_template :new }
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'assigns plan_data with product_name and purchase_link' do
          get_new

          expect(assigns(:plan_data)).to include(
            name: 'GitLab Credits - Monthly Committed Pool',
            purchase_link: {
              href: a_string_including(
                '/subscriptions/purchases/gitlab?deployment_type=gitlab_com&plan_type=gitlab_credits'
              )
            }
          )
        end

        context 'when promo_code is also provided' do
          subject(:get_new) do
            get new_gitlab_subscriptions_group_path, params: {
              plan_type: 'gitlab_credits',
              product_name: 'GitLab Credits',
              promo_code: 'PROMO123'
            }
            response
          end

          it 'assigns the promo code' do
            get_new

            expect(assigns(:promo_code)).to eq 'PROMO123'
          end
        end

        context 'when tier is also provided' do
          subject(:get_new) do
            get new_gitlab_subscriptions_group_path, params: {
              plan_type: 'gitlab_credits',
              product_name: 'GitLab Credits',
              tier: 'premium'
            }
            response
          end

          it 'assigns the tier' do
            get_new

            expect(assigns(:tier)).to eq 'premium'
          end

          it 'includes tier in the purchase link' do
            get_new

            expect(assigns(:plan_data)[:purchase_link][:href]).to include('tier=premium')
          end
        end

        context 'when entry_point is provided' do
          it 'includes the entry_point in the purchase link' do
            get new_gitlab_subscriptions_group_path, params: {
              plan_type: 'gitlab_credits',
              product_name: 'GitLab Credits',
              entry_point: 'test-entry-point'
            }

            expect(assigns(:plan_data)[:purchase_link][:href]).to include('entry_point=test-entry-point')
          end
        end

        context 'when utm params are provided' do
          it 'includes sanitised versions of all permitted params in the purchase link' do
            get new_gitlab_subscriptions_group_path, params: {
              plan_type: 'gitlab_credits',
              product_name: 'GitLab Credits',
              utm_source: 'test-source',
              utm_medium: '<script>email</script>',
              other_utm_param: 'test-value'
            }

            expect(assigns(:plan_data)[:purchase_link][:href]).to include('utm_source=test-source')
            expect(assigns(:plan_data)[:purchase_link][:href]).to include('utm_medium=email')
            expect(assigns(:plan_data)[:purchase_link][:href]).not_to include('other_utm_param')
          end
        end

        context 'when the user has existing namespaces' do
          let_it_be(:owned_group) { create(:group) }
          let_it_be(:maintainer_group) { create(:group) }
          let_it_be(:developer_group) { create(:group) }

          before_all do
            owned_group.add_owner(user)
            maintainer_group.add_maintainer(user)
            developer_group.add_developer(user)
          end

          it 'passes check_subscription_status to the finder' do
            expect(GitlabSubscriptions::PurchaseEligibleNamespacesFinder).to receive(:new).with(
              user: user,
              plan_id: nil,
              check_subscription_status: false
            ).and_call_original

            get_new
          end

          it 'assigns all owned top-level groups as eligible' do
            get_new

            expect(assigns(:eligible_groups)).to match_array [owned_group]
          end
        end

        context 'when the user does not have existing namespaces' do
          it 'assigns the eligible groups for the subscription' do
            get_new

            expect(assigns(:eligible_groups)).to be_empty
          end
        end
      end

      context 'when the plan cannot be found' do
        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([])
          end
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when the user does not have existing namespaces' do
        let(:plan_data) { { id: 'plan-id' } }

        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([plan_data])
          end
        end

        it { is_expected.to render_template 'layouts/minimal' }
        it { is_expected.to render_template :new }
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'assigns the eligible groups for the subscription' do
          get_new

          expect(assigns(:eligible_groups)).to be_empty
        end

        it 'assigns the plan data' do
          get_new

          expect(assigns(:plan_data)).to eq plan_data
        end
      end

      context 'when the user has existing namespaces' do
        let(:plan_data) { { id: 'plan-id' } }

        let_it_be(:owned_group) { create(:group) }
        let_it_be(:maintainer_group) { create(:group) }
        let_it_be(:developer_group) { create(:group) }

        before_all do
          owned_group.add_owner(user)
          maintainer_group.add_maintainer(user)
          developer_group.add_developer(user)
        end

        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([plan_data])
          end

          allow_next_instance_of(
            GitlabSubscriptions::PurchaseEligibleNamespacesFinder,
            user: user, plan_id: 'plan-id', check_subscription_status: true
          ) do |finder|
            allow(finder).to receive(:execute).and_return([owned_group])
          end
        end

        it { is_expected.to render_template 'layouts/minimal' }
        it { is_expected.to render_template :new }
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'assigns the eligible groups for the subscription' do
          get_new

          expect(assigns(:eligible_groups)).to match_array [owned_group]
        end

        it 'assigns the plan data' do
          get_new

          expect(assigns(:plan_data)).to eq plan_data
        end

        context 'when promo_code is provided' do
          subject(:get_new) do
            get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id', promo_code: 'promo_code' }
            response
          end

          it 'assigns the promo code' do
            get_new

            expect(assigns(:promo_code)).to eq 'promo_code'
          end
        end

        context 'when tier is provided' do
          subject(:get_new) do
            get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id', tier: 'ultimate' }
            response
          end

          it 'assigns the tier' do
            get_new

            expect(assigns(:tier)).to eq 'ultimate'
          end
        end

        context 'when both promo_code and tier are provided' do
          subject(:get_new) do
            get new_gitlab_subscriptions_group_path,
              params: { plan_id: 'plan-id', promo_code: 'promo_code', tier: 'ultimate' }
            response
          end

          it 'assigns both promo_code and tier' do
            get_new

            expect(assigns(:promo_code)).to eq 'promo_code'
            expect(assigns(:tier)).to eq 'ultimate'
          end
        end
      end
    end
  end

  describe 'POST #create', :with_current_organization do
    subject(:post_create) do
      post gitlab_subscriptions_groups_path, params: params
      response
    end

    let(:params) { { group: { name: 'Test Group' }, plan_id: 'plan-id' } }

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
      end

      context 'with valid params' do
        context 'when no path is provided' do
          it 'creates a new group' do
            expect { post_create }.to change { user.groups.count }.from(0).to(1)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to eq('id' => user.groups.last.id)
            expect(user.groups.last.name).to eq('Test Group')
          end
        end

        context 'when path is provided' do
          let(:params) { { group: { name: 'Test Group', path: 'test-group123' } } }

          it 'creates a new group' do
            expect { post_create }.to change { user.groups.count }.from(0).to(1)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to eq('id' => user.groups.last.id)
            expect(user.groups.last.name).to eq('Test Group')
            expect(user.groups.last.path).to eq('test-group123')
          end
        end
      end

      context 'when a namespace already exists with the same name' do
        let(:params) { { group: { name: 'Test Group' } } }

        it 'creates the group with a different path' do
          create(:group, name: 'Test Group', path: 'test-group')

          expect { post_create }.to change { user.groups.count }.from(0).to(1)
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to eq('id' => user.groups.last.id)
        end
      end

      context 'with invalid params' do
        let(:params) { { group: { name: '' }, plan_id: 'plan-id' } }

        it 'has the unprocessable entity status and the errors' do
          post_create

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to match(
            'errors' => {
              "name" => array_including("can't be blank")
            }
          )
        end
      end
    end
  end
end
