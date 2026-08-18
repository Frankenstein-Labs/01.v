# frozen_string_literal: true

require('spec_helper')

RSpec.describe Projects::Settings::CiCdController, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: group, maintainers: user) }

  let(:current_user) { user }

  context 'as a maintainer' do
    before do
      sign_in(current_user)
    end

    describe 'GET show' do
      let!(:protected_environment) { create(:protected_environment, project: project) }
      let!(:group_protected_environment) { create(:protected_environment, group: group, project: nil) }
      let!(:parent_group_protected_environment) { create(:protected_environment, group: parent_group, project: nil) }

      it 'renders group protected environments' do
        get :show, params: { namespace_id: project.namespace, project_id: project }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
        expect(subject.view_assigns['group_protected_environments'])
          .to match_array([group_protected_environment, parent_group_protected_environment])
      end
    end

    describe 'PATCH update' do
      subject do
        patch :update, params: {
          namespace_id: project.namespace.to_param,
          project_id: project,
          project: params
        }
      end

      context 'when restrict_pipeline_cancellation_role is specified' do
        let(:params) { { restrict_pipeline_cancellation_role: :maintainer } }
        let(:request) do
          patch :update, params: {
            namespace_id: project.namespace.to_param,
            project_id: project,
            project: params
          }
        end

        shared_examples 'no update' do
          it 'role does not update' do
            expect { request }.to not_change {
              project.ci_cd_settings.reload.restrict_pipeline_cancellation_role_maintainer?
            }.and not_change {
                    project.ci_cd_settings.reload.restrict_pipeline_cancellation_role_developer?
                  }
          end
        end

        shared_examples 'update' do
          it 'role updates' do
            expect { request }.to change {
              project.ci_cd_settings.reload.restrict_pipeline_cancellation_role_maintainer?
            }.from(false).to(true).and change {
                                         project.ci_cd_settings.reload.restrict_pipeline_cancellation_role_developer?
                                       }.from(true).to(false)
          end
        end

        context 'when the feature is enabled' do
          before do
            allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
              allow(cr).to receive(:feature_available?).and_return(true)
            end
          end

          context 'when the user has permission' do
            it_behaves_like 'update'
          end

          context 'when the user has no permission' do
            let(:current_user) { create(:user) }

            it_behaves_like 'no update'
          end
        end

        context 'when the feature is disabled' do
          before do
            allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
              allow(cr).to receive(:feature_available?).and_return(false)
            end
          end

          context 'when the user has permission' do
            it_behaves_like 'no update'
          end

          context 'when the user has no permission' do
            let(:current_user) { create(:user) }

            it_behaves_like 'no update'
          end
        end
      end

      context 'when updating general settings' do
        context 'when allow_pipeline_trigger_approve_deployment is specified' do
          let(:params) { { allow_pipeline_trigger_approve_deployment: true } }

          it 'sets allow_pipeline_trigger_approve_deployment' do
            expect { subject }.to change {
              project.reload.allow_pipeline_trigger_approve_deployment
            }.from(false).to(true)
          end
        end

        context 'when allow_composite_identities_to_run_pipelines is specified' do
          let(:params) do
            { ci_cd_settings_attributes: {
              allow_composite_identities_to_run_pipelines: true
            } }
          end

          it 'sets allow_composite_identities_to_run_pipelines' do
            expect { subject }.to change {
              project.reload.ci_cd_settings.allow_composite_identities_to_run_pipelines
            }.from(false).to(true)
          end
        end
      end
    end
  end
end
