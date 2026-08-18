# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::RunnersController, feature_category: :fleet_visibility do
  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let(:user) { owner }

  before do
    sign_in(user)
  end

  shared_examples 'controller pushes runner upgrade management features' do
    before do
      allow(controller).to receive(:push_licensed_feature)
    end

    it 'enables runner_upgrade_management_for_namespace licensed feature' do
      make_request

      is_expected.to have_received(:push_licensed_feature).with(:runner_upgrade_management_for_namespace, group)
    end

    context 'when fetching runner releases is disabled' do
      before do
        stub_application_setting(update_runner_versions_enabled: false)
      end

      it 'does not enable runner_upgrade_management_for_namespace licensed feature' do
        make_request

        is_expected.not_to have_received(:push_licensed_feature).with(:runner_upgrade_management_for_namespace)
      end
    end
  end

  shared_examples 'controller pushes maintenance note feature' do
    before do
      allow(controller).to receive(:push_licensed_feature)
    end

    it 'enables runner_maintenance_note_for_namespace licensed feature' do
      make_request

      is_expected.to have_received(:push_licensed_feature).with(:runner_maintenance_note_for_namespace, group)
    end
  end

  describe '#index' do
    let(:make_request) do
      get :index, params: { group_id: group }
    end

    it_behaves_like 'controller pushes runner upgrade management features'

    context 'when user is developer' do
      let(:user) { developer }

      it 'returns not found' do
        make_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#new' do
    let(:make_request) do
      get :new, params: { group_id: group }
    end

    it_behaves_like 'controller pushes maintenance note feature'
  end

  describe '#show' do
    let(:make_request) do
      get :show, params: { group_id: group, id: runner }
    end

    let(:runner) { create(:ci_runner, :group, groups: [group]) }

    it_behaves_like 'controller pushes runner upgrade management features'

    it_behaves_like 'controller pushes maintenance note feature'

    context 'when user is developer' do
      let(:user) { developer }

      it 'returns not found' do
        make_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#edit' do
    let(:make_request) do
      get :edit, params: { group_id: group, id: runner }
    end

    let(:runner) { create(:ci_runner, :group, groups: [group]) }

    it_behaves_like 'controller pushes maintenance note feature'
  end

  describe '#dashboard' do
    let(:make_request) do
      get :dashboard, params: { group_id: group }
    end

    let(:runner) { create(:ci_runner, :group, groups: [group]) }
    let(:feature_available) { true }

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: feature_available)
    end

    it_behaves_like 'controller pushes runner upgrade management features'

    context 'when user is developer' do
      let(:user) { developer }

      it 'returns not found' do
        make_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when feature is not available' do
      let(:feature_available) { false }

      it 'returns not found' do
        make_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
