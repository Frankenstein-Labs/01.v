# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::SeatUtilizationController, type: :request, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  subject(:get_index) { get group_settings_gitlab_duo_seat_utilization_index_path(group) }

  before do
    stub_licensed_features(code_suggestions: true)
    sign_in(user)
  end

  shared_examples 'redirects to gitlab duo home path' do
    it 'redirects to gitlab duo home path for the group' do
      get_index

      expect(response).to redirect_to(group_settings_gitlab_duo_path(group))
    end
  end

  shared_examples 'renders seat management index page for group' do
    it 'renders duo seat management index page for group' do
      get_index

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  shared_examples 'renders not found error' do
    it 'renders not found error' do
      get_index

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when user has read_usage_quotas permission' do
    let(:add_on_type) { :duo_pro }
    let!(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on_type, quantity: 50, namespace: group)
    end

    before_all do
      group.add_owner(user)
    end

    context "when show_gitlab_duo_settings_app? returns false" do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it_behaves_like 'renders not found error'
    end

    context "when show_gitlab_duo_settings_app? returns true", :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'renders seat management index page for group'
    end

    context 'with a non seat assignable duo add on', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when duo core add on is provisioned' do
        let(:add_on_type) { :duo_core }

        it_behaves_like 'redirects to gitlab duo home path'
      end

      context 'when duo amazon q add on is provisioned' do
        let(:add_on_type) { :duo_amazon_q }

        it_behaves_like 'redirects to gitlab duo home path'
      end
    end

    context 'when in a subgroup', :saas do
      let(:subgroup) { create(:group, :private, parent: group) }

      before do
        subgroup.add_owner(user)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "renders 404" do
        get group_settings_gitlab_duo_seat_utilization_index_path(subgroup)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when user does not have read_usage_quotas permission', :saas do
    before do
      group.add_maintainer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- cannot use stub_saas_features in before_all
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it_behaves_like 'renders not found error'
  end
end
