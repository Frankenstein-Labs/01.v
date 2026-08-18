# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationsController, feature_category: :system_access do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:application) { create(:oauth_application, owner_id: nil, owner_type: nil) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    subject(:get_index) { get :index }

    it { is_expected.to have_gitlab_http_status(:ok) }

    it 'sets the total count' do
      get_index

      expect(assigns(:applications_total_count)).to eq(1)
      expect(assigns(:applications).has_next_page?).to be_falsey
    end

    context 'when more than 20 applications' do
      before do
        create_list(:oauth_application, 20, owner_id: nil, owner_type: nil) # rubocop:disable FactoryBot/ExcessiveCreateList -- paginator shows if > 20 applications
      end

      it 'has paginator' do
        get_index

        expect(assigns(:applications_total_count)).to eq(21)
        expect(assigns(:applications).has_next_page?).to be_truthy
      end
    end
  end

  describe 'POST #create' do
    it 'creates the application' do
      stub_licensed_features(extended_audit_events: true)

      create_params = attributes_for(:application, trusted: true)

      expect do
        post :create, params: { authn_oauth_application: create_params }
      end.to change { AuditEventReader.count }.by(1)
    end
  end
end
