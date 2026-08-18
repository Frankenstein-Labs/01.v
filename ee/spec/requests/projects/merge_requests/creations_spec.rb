# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'merge requests creations', feature_category: :code_review_workflow do
  describe 'POST /:namespace/:project/merge_requests' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:user) { create(:user, :with_namespace, developer_of: group) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let(:merge_request) { MergeRequest.last }
    let(:create_merge_request_params) do
      {
        namespace_id: project.namespace.to_param,
        project_id: project,
        merge_request: {
          source_branch: 'feature',
          target_branch: 'master',
          title: 'Test merge request',
          description: description
        }
      }
    end

    subject(:send_request) do
      post namespace_project_merge_requests_path(create_merge_request_params)
    end

    before do
      login_as(user)
    end

    describe 'Duo code review assignment handling' do
      include_examples 'handle quickactions without Duo access'

      context 'when automatic Duo code review is enabled' do
        let(:project) { create(:project, :repository, group: group) }
        let(:duo_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }
        let(:description) { "" }
        let(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }

        before do
          allow(Gitlab::Duo::CodeReview).to receive(:enabled?)
            .with(user: user, container: project).and_return(has_duo_access)

          project.project_setting.update_attribute(:auto_duo_code_review_enabled, true)
          project.project_setting.update!(duo_features_enabled: true)
        end

        context 'with Duo Enterprise add-on (classic flow)' do
          before do
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
          end

          context 'when user lacks Duo access' do
            let(:has_duo_access) { false }

            it 'does not assign Duo bot as a reviewer and shows access error message' do
              send_request
              expect(response).to redirect_to(project_merge_request_path(project, merge_request))
              follow_redirect!
              expect(flash[:alert]).to include("GitLab Duo Code Review was not automatically added")
              expect(merge_request.reload.reviewers).not_to include(duo_bot)
            end
          end

          context 'when user has Duo access' do
            let(:has_duo_access) { true }

            context 'when duo_code_review_dap_internal_users is enabled' do
              before do
                stub_feature_flags(duo_code_review_dap_internal_users: true)
                allow_next_instance_of(MergeRequest) do |instance|
                  allow(instance).to receive(:ai_review_merge_request_allowed?).with(user).and_return(true)
                end
              end

              it 'assigns Duo bot as a reviewer using DAP for internal users' do
                send_request
                expect(response).to redirect_to(project_merge_request_path(project, merge_request))
                follow_redirect!
                expect(flash[:alert]).to be_nil
                expect(merge_request.reload.reviewers).to include(duo_bot)
              end
            end

            context 'when duo_code_review_dap_internal_users is disabled' do
              before do
                stub_feature_flags(duo_code_review_dap_internal_users: false)
              end

              it 'assigns Duo bot as a reviewer using classic flow' do
                send_request
                expect(response).to redirect_to(project_merge_request_path(project, merge_request))
                follow_redirect!
                expect(flash[:alert]).to be_nil
                expect(merge_request.reload.reviewers).to include(duo_bot)
              end
            end
          end
        end

        context 'with DAP flow (Duo Core/Pro add-ons)' do
          let(:has_duo_access) { true }
          let_it_be(:code_review_foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }

          before do
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)
            project.project_setting.update!(duo_foundational_flows_enabled: true)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(false)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?)
              .with(project, :duo_workflow).and_return(true)
            allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
              .with('code_review/v1')
              .and_return(
                instance_double(
                  ::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow
                )
              )
            create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: project.root_ancestor,
              catalog_item: code_review_foundational_flow)
            allow_next_instance_of(MergeRequest) do |instance|
              allow(instance).to receive(:ai_review_merge_request_allowed?).with(user).and_return(true)
            end
          end

          it 'assigns Duo bot as a reviewer' do
            send_request
            expect(response).to redirect_to(project_merge_request_path(project, merge_request))
            follow_redirect!
            expect(flash[:alert]).to be_nil
            expect(merge_request.reload.reviewers).to include(duo_bot)
          end
        end
      end
    end
  end
end
