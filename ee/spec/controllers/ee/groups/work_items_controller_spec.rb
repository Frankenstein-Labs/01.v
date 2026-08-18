# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::WorkItemsController, feature_category: :team_planning do
  describe 'DescriptionDiffActions' do
    let_it_be(:group) { create(:group, :public) }
    let(:group_params) { { group_id: group, iid: issuable.iid } }

    context 'when issuable is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, :group_level, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end

    context 'when work item is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:work_item, :group_level, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end

    context 'when issuable is a task/work_item' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:work_item, :group_level, :task, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end
  end

  describe 'GET #show' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:current_user) { create(:user, developer_of: group) }
    let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

    before do
      sign_in(current_user)
      stub_licensed_features(epics: true)
    end

    context 'when work item type is not epic' do
      it 'sets the ApplicationContext with an ai_resource key' do
        get :show, params: { group_id: group, iid: work_item.iid }

        expect(response).to have_gitlab_http_status(:ok)
        expect(::Gitlab::ApplicationContext.current).to include(
          'meta.ai_resource' => work_item.try(:to_global_id)
        )
      end
    end

    context 'with an epic work item' do
      let(:epic_work_item) { create(:work_item, :epic, :group_level, namespace: group) }

      it 'does not redirect to the group epics path' do
        get :show, params: { group_id: group, iid: epic_work_item.iid }

        expect(response).not_to redirect_to group_epic_path(group, epic_work_item.iid)
      end
    end
  end
end
