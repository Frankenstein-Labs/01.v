# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::WorkItemsController, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, :public, developers: user) }
  let_it_be(:project) { create(:project_empty_repo, :public, namespace: namespace) }
  let_it_be(:work_item) { create(:work_item, project: project) }

  before do
    sign_in(user)
  end

  describe '#new' do
    it_behaves_like 'EE: issue building actions',
      assigned_name: :work_item
  end

  describe 'licensed features' do
    describe 'generate_description feature' do
      before do
        allow(controller).to receive(:push_licensed_feature)
      end

      context 'when user can generate description' do
        before do
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(user, :generate_description, project).and_return(true)
        end

        describe 'GET #show' do
          context 'when generate_description is licensed' do
            before do
              stub_licensed_features(generate_description: true)
            end

            it 'pushes generate_description licensed feature' do
              get :show, params: { namespace_id: project.namespace, project_id: project, iid: work_item.iid }

              expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
            end
          end

          context 'when generate_description is not licensed' do
            before do
              stub_licensed_features(generate_description: false)
            end

            it 'pushes generate_description licensed feature when user has permission regardless of license status' do
              get :show, params: { namespace_id: project.namespace, project_id: project, iid: work_item.iid }

              expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
            end
          end
        end

        describe 'GET #index' do
          context 'when generate_description is licensed' do
            before do
              stub_licensed_features(generate_description: true)
            end

            it 'pushes generate_description licensed feature' do
              get :index, params: { namespace_id: project.namespace, project_id: project }

              expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
            end
          end

          context 'when generate_description is not licensed' do
            before do
              stub_licensed_features(generate_description: false)
            end

            it 'pushes generate_description licensed feature when user has permission regardless of license status' do
              get :index, params: { namespace_id: project.namespace, project_id: project }

              expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
            end
          end
        end
      end

      context 'when user cannot generate description' do
        before do
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(user, :generate_description, project).and_return(false)
          stub_licensed_features(generate_description: true)
        end

        describe 'GET #show' do
          it 'does not push generate_description licensed feature' do
            get :show, params: { namespace_id: project.namespace, project_id: project, iid: work_item.iid }

            expect(controller).not_to have_received(:push_licensed_feature)
          end
        end

        describe 'GET #index' do
          it 'does not push generate_description licensed feature' do
            get :index, params: { namespace_id: project.namespace, project_id: project }

            expect(controller).not_to have_received(:push_licensed_feature)
          end
        end
      end

      context 'when work item is a context for duo chat' do
        it 'sets the ApplicationContext with an ai_resource key' do
          get :show, params: { namespace_id: project.namespace, project_id: project, iid: work_item.iid }

          expect(Gitlab::ApplicationContext.current).to include(
            'meta.ai_resource' => work_item.try(:to_global_id)
          )
        end
      end
    end
  end
end
