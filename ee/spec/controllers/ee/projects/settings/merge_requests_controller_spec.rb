# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::MergeRequestsController, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, maintainers: user) }

  before do
    sign_in(user)
  end

  describe 'PUT #update' do
    it 'updates Issuable Default Templates attributes' do
      params = {
        merge_requests_template: 'I got tissues'
      }

      put :update, params: {
        namespace_id: project.namespace,
        project_id: project,
        project: params
      }
      project.reload

      expect(response).to have_gitlab_http_status(:found)
      params.each do |param, value|
        expect(project.public_send(param)).to eq(value)
      end
    end

    context 'when merge_pipelines_enabled param is specified' do
      let(:params) { { merge_pipelines_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      context 'when feature is available through license' do
        before do
          stub_licensed_features(merge_pipelines: true)
        end

        it 'updates the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_truthy
        end
      end

      context 'when feature is available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'updates the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_truthy
        end
      end

      context 'when usage ping is disabled on free license' do
        before do
          stub_usage_ping_features(false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_falsy
        end
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_pipelines: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_falsy
        end
      end
    end

    context 'when suggested_reviewers_enabled param is specified' do
      let(:params) { { project_setting_attributes: { suggested_reviewers_enabled: '1' } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      it 'updates the attribute' do
        allow_any_instance_of(Project).to receive(:suggested_reviewers_available?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf

        request
        expect(project.reload.suggested_reviewers_enabled).to be(true)
      end
    end

    context 'when auto_duo_code_review_enabled param is specified' do
      let(:params) { { project_setting_attributes: { auto_duo_code_review_enabled: '1' } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      it 'updates the attribute' do
        request
        expect(project.reload.auto_duo_code_review_enabled).to be(true)
      end
    end

    context 'when merge_trains_enabled param is specified' do
      let(:params) { { merge_trains_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
      end

      it 'updates the attribute' do
        request

        expect(project.merge_trains_enabled).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.merge_trains_enabled).to be_falsy
        end
      end
    end

    context 'when merge_trains_skip_train_allowed param is specified' do
      let(:params) { { merge_trains_skip_train_allowed: true } }
      let(:ci_settings) { project.ci_cd_settings }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
      end

      it 'updates the attribute' do
        request

        expect(ci_settings.merge_trains_skip_train_allowed).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        it 'does not update the attribute' do
          request

          expect(ci_settings.merge_trains_skip_train_allowed).to be_falsy
        end
      end
    end

    context 'when only_allow_merge_if_all_status_checks_passed param is specified' do
      let(:params) { { project_setting_attributes: { only_allow_merge_if_all_status_checks_passed: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      it_behaves_like 'update only allow merge if all status checks passed'
    end

    context 'when security_policy_pipeline_must_succeed param is specified' do
      let(:params) { { project_setting_attributes: { security_policy_pipeline_must_succeed: '1' } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      context 'when feature flag and license are available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
          stub_feature_flags(security_policy_pipeline_check: true)
        end

        it 'updates the attribute' do
          expect(::Security::PolicyAvailability).to receive(:available?).with(project, :security_orchestration_policies)
            .at_least(:once).and_call_original

          request

          expect(project.reload.security_policy_pipeline_must_succeed).to be(true)
        end
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.security_policy_pipeline_must_succeed).to be(false)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
          stub_feature_flags(security_policy_pipeline_check: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.security_policy_pipeline_must_succeed).to be(false)
        end
      end
    end

    context 'when auto_rollback_enabled param is specified' do
      let(:params) { { auto_rollback_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      before do
        stub_licensed_features(auto_rollback: true)
      end

      it 'updates the attribute' do
        request

        expect(project.reload.auto_rollback_enabled).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(auto_rollback: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.auto_rollback_enabled).to be_falsy
        end
      end
    end

    describe 'merge request approvers settings' do
      shared_examples 'merge request approvers rules' do
        using RSpec::Parameterized::TableSyntax

        where(:can_modify, :param_value, :final_value) do
          true  | true  | true
          true  | false | false
          false | true  | nil
          false | false | nil
        end

        with_them do
          before do
            allow(controller).to receive(:can?).and_call_original
            allow(controller).to receive(:can?).with(user, rule_name, project).and_return(can_modify)
          end

          it 'updates project if needed' do
            put :update,
              params: {
                namespace_id: project.namespace,
                project_id: project,
                project: { setting => param_value }
              }

            project.reload

            expect(project[setting]).to eq(final_value.nil? ? setting_default_value : final_value)
          end
        end
      end

      describe ':disable_overriding_approvers_per_merge_request' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_approvers_rules }
          let(:setting) { :disable_overriding_approvers_per_merge_request }
          let(:setting_default_value) { nil }
        end
      end

      describe ':merge_requests_author_approval' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_merge_request_author_setting }
          let(:setting) { :merge_requests_author_approval }
          let(:setting_default_value) { false }
        end
      end

      describe ':merge_requests_disable_committers_approval' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_merge_request_committer_setting }
          let(:setting) { :merge_requests_disable_committers_approval }
          let(:setting_default_value) { nil }
        end
      end

      context 'with security_orchestration_policies licensed feature enabled' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'pushes security_orchestration_policies licensed feature' do
          expect(controller).to receive(:push_licensed_feature).with(:security_orchestration_policies)

          put :update, params: {
            namespace_id: project.namespace,
            project_id: project,
            project: { disable_overriding_approvers_per_merge_request: true }
          }
        end
      end

      it 'does not push security_orchestration_policies licensed feature' do
        expect(controller).not_to receive(:push_licensed_feature).with(:security_orchestration_policies)

        put :update, params: {
          namespace_id: project.namespace,
          project_id: project,
          project: { disable_overriding_approvers_per_merge_request: true }
        }
      end
    end

    context 'when security_policy_pipeline_check feature flag is enabled and license is available' do
      before do
        stub_feature_flags(security_policy_pipeline_check: true)
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'allows security_policy_pipeline_must_succeed param' do
        put :update, params: {
          namespace_id: project.namespace,
          project_id: project,
          project: { project_setting_attributes: { security_policy_pipeline_must_succeed: '1' } }
        }

        expect(project.reload.security_policy_pipeline_must_succeed).to be(true)
      end
    end

    context 'when security_policy_pipeline_check feature flag is enabled but license is unavailable' do
      before do
        stub_feature_flags(security_policy_pipeline_check: true)
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not allow security_policy_pipeline_must_succeed param' do
        put :update, params: {
          namespace_id: project.namespace,
          project_id: project,
          project: { project_setting_attributes: { security_policy_pipeline_must_succeed: '1' } }
        }

        expect(project.reload.security_policy_pipeline_must_succeed).to be(false)
      end
    end

    context 'when merge_request_title_regex params are specified' do
      let(:params) do
        { merge_request_title_regex: '/aaa/', merge_request_title_regex_description: 'Description of regex' }
      end

      let(:request) do
        put :update, params: { namespace_id: project.namespace, project_id: project, project: params }
      end

      it 'updates the attributes' do
        request

        project.reload

        expect(project.merge_request_title_regex).to eq('/aaa/')
        expect(project.merge_request_title_regex_description).to eq('Description of regex')
      end
    end

    context 'when reviewer_assignment_strategy param is specified' do
      it 'updates reviewer_assignment_strategy to code_owners' do
        expect(project.project_setting.reviewer_assignment_strategy).to eq('disabled')

        put :update, params: {
          namespace_id: project.namespace,
          project_id: project,
          project: {
            project_setting_attributes: {
              reviewer_assignment_strategy: 'code_owners'
            }
          }
        }

        expect(response).to redirect_to(project_settings_merge_requests_path(project))
        expect(project.project_setting.reload.reviewer_assignment_strategy).to eq('code_owners')
      end

      it 'updates reviewer_assignment_strategy to disabled' do
        project.project_setting.update!(reviewer_assignment_strategy: :code_owners)

        put :update, params: {
          namespace_id: project.namespace,
          project_id: project,
          project: {
            project_setting_attributes: {
              reviewer_assignment_strategy: 'disabled'
            }
          }
        }

        expect(response).to redirect_to(project_settings_merge_requests_path(project))
        expect(project.project_setting.reload.reviewer_assignment_strategy).to eq('disabled')
      end

      context 'when code_owners license is not available' do
        before do
          stub_licensed_features(code_owners: false)
        end

        it 'does not update reviewer_assignment_strategy' do
          put :update, params: {
            namespace_id: project.namespace,
            project_id: project,
            project: {
              project_setting_attributes: {
                reviewer_assignment_strategy: 'code_owners'
              }
            }
          }

          expect(response).to redirect_to(project_settings_merge_requests_path(project))
          expect(project.project_setting.reload.reviewer_assignment_strategy).to eq('disabled')
        end
      end
    end
  end
end
