# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::Project, feature_category: :shared do
  let_it_be(:project) { create(:project) }

  let(:options) { {} }
  let(:developer) { create(:user, developer_of: project) }
  let(:guest) { create(:user, guest_of: project) }
  let(:maintainer) { create(:user, maintainer_of: project) }

  let(:entity) do
    ::API::Entities::Project.new(project, options)
  end

  subject { entity.as_json }

  context 'compliance_frameworks' do
    context 'when project has a compliance framework' do
      let(:project) { create(:project, :with_sox_compliance_framework) }

      it 'is an array containing all the compliance frameworks' do
        expect(subject[:compliance_frameworks]).to match_array(['SOX'])
      end
    end

    context 'when project has compliance frameworks' do
      let_it_be(:project) { create(:project, :with_multiple_compliance_frameworks) }

      it 'is an array containing all the compliance frameworks' do
        expect(subject[:compliance_frameworks]).to contain_exactly('SOX', 'GDPR')
      end
    end

    context 'when project has no compliance framework' do
      let(:project) { create(:project) }

      it 'is empty array when project has no compliance framework' do
        expect(subject[:compliance_frameworks]).to eq([])
      end
    end
  end

  describe 'ci_restrict_pipeline_cancellation_role' do
    let(:options) { { current_user: current_user } }

    context 'when user has maintainer permission or above' do
      let(:current_user) { project.owner }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to eq 'developer' }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be_nil }
      end
    end

    context 'when user permission is below maintainer' do
      let(:current_user) { developer }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be_nil }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be_nil }
      end
    end

    def mock_available
      allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
        allow(cr).to receive(:feature_available?).and_return(true)
      end
    end
  end

  describe 'secret_push_protection_enabled' do
    let_it_be(:project) { create(:project) }
    let(:options) { { current_user: current_user } }

    before do
      stub_licensed_features(secret_push_protection: true)
    end

    shared_examples 'returning nil' do
      it 'returns nil' do
        expect(subject[:secret_push_protection_enabled]).to be_nil
      end
    end

    context 'when user does not have access' do
      context 'when project does not have proper license' do
        let(:current_user) { developer }

        before do
          stub_licensed_features(secret_push_protection: false)
        end

        it_behaves_like 'returning nil'
      end

      context 'when user is guest' do
        let(:current_user) { guest }

        it_behaves_like 'returning nil'
      end
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it 'returns a boolean' do
        expect(subject[:secret_push_protection_enabled]).to be_in([true, false])
      end
    end
  end

  describe 'auto_duo_code_review_enabled' do
    let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:code_review_foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }

    context 'when project has auto_duo_code_review_settings available' do
      context 'on SaaS', :saas do
        where(:add_on_type, :add_on) do
          [
            ['duo_enterprise', ref(:duo_enterprise_add_on)],
            ['duo_core',       ref(:duo_core_add_on)],
            ['duo_pro',        ref(:duo_pro_add_on)]
          ]
        end

        with_them do
          let(:entity_subject) { ::API::Entities::Project.new(project_in_group, {}).as_json }

          before do
            stub_ee_application_setting(should_check_namespace_plan: true)
            allow(project_in_group).to receive_messages(
              duo_features_enabled: true,
              duo_foundational_flows_enabled: true
            )
            allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
              .with('code_review/v1')
              .and_return(
                instance_double(::Ai::Catalog::FoundationalFlow,
                  catalog_item: code_review_foundational_flow)
              )
            create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: group,
              catalog_item: code_review_foundational_flow)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?)
              .with(project_in_group, :duo_workflow).and_return(true)
            create(:gitlab_subscription_add_on_purchase, namespace: group, add_on: add_on)
          end

          it "returns a boolean value for #{params[:add_on_type]}" do
            expect(entity_subject[:auto_duo_code_review_enabled]).to be_in([true, false])
          end
        end
      end
    end

    context 'when project does not have auto_duo_code_review_settings available' do
      context 'without any add-on' do
        before do
          allow(project).to receive(:duo_features_enabled).and_return(true)
        end

        it 'returns nil' do
          expect(subject[:auto_duo_code_review_enabled]).to be_nil
        end
      end

      context 'when duo_features_enabled is false' do
        before do
          allow(project).to receive(:duo_features_enabled).and_return(false)
        end

        it 'returns nil' do
          expect(subject[:auto_duo_code_review_enabled]).to be_nil
        end
      end

      context 'with add-on but duo_foundational_flows_enabled is false', :saas do
        let(:entity_subject) { ::API::Entities::Project.new(project_in_group, {}).as_json }

        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
          allow(project_in_group).to receive_messages(
            duo_features_enabled: true,
            duo_foundational_flows_enabled: false
          )
          create(:gitlab_subscription_add_on_purchase, namespace: group, add_on: duo_core_add_on)
        end

        it 'returns nil because duo_foundational_flows_enabled is false' do
          expect(entity_subject[:auto_duo_code_review_enabled]).to be_nil
        end
      end

      context 'with add-on but code_review flow is not enabled', :saas do
        let(:entity_subject) { ::API::Entities::Project.new(project_in_group, {}).as_json }

        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
          allow(project_in_group).to receive_messages(
            duo_features_enabled: true,
            duo_foundational_flows_enabled: true
          )
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
            .with('code_review/v1')
            .and_return(
              instance_double(::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow)
            )
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
            .with(project_in_group, :duo_workflow).and_return(true)
          create(:gitlab_subscription_add_on_purchase, namespace: group, add_on: duo_core_add_on)
        end

        it 'returns nil because code_review flow is not enabled' do
          expect(entity_subject[:auto_duo_code_review_enabled]).to be_nil
        end
      end

      context 'with add-on but StageCheck returns false', :saas do
        let(:entity_subject) { ::API::Entities::Project.new(project_in_group, {}).as_json }

        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
          allow(project_in_group).to receive_messages(
            duo_features_enabled: true,
            duo_foundational_flows_enabled: true
          )
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
            .with('code_review/v1')
            .and_return(
              instance_double(::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow)
            )
          create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: group,
            catalog_item: code_review_foundational_flow)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
            .with(project_in_group, :duo_workflow).and_return(false)
          create(:gitlab_subscription_add_on_purchase, namespace: group, add_on: duo_core_add_on)
        end

        it 'returns nil because StageCheck returns false' do
          expect(entity_subject[:auto_duo_code_review_enabled]).to be_nil
        end
      end
    end
  end

  describe 'duo_remote_flows_enabled' do
    context 'when project is licensed to use duo_agent_platform' do
      before do
        stub_licensed_features(ai_workflows: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_remote_flows_enabled]).to be_in([true, false])
      end
    end

    context 'when project is not licensed to use duo_agent_platform' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_workflows: false)
      end

      it 'returns nil' do
        expect(subject[:duo_remote_flows_enabled]).to be_nil
      end
    end
  end

  describe 'duo_foundational_flows_enabled' do
    context 'when project is licensed to use duo_agent_platform' do
      before do
        stub_licensed_features(ai_workflows: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_foundational_flows_enabled]).to be_in([true, false])
      end
    end

    context 'when project is not licensed to use duo_agent_platform' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_workflows: false)
      end

      it 'returns nil' do
        expect(subject[:duo_foundational_flows_enabled]).to be_nil
      end
    end
  end

  describe 'duo_sast_fp_detection_enabled' do
    context 'when project is licensed to use ai_features' do
      before do
        stub_licensed_features(ai_features: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_sast_fp_detection_enabled]).to be_in([true, false])
      end
    end

    context 'when project is not licensed to use ai_features' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_features: false)
      end

      it 'returns nil' do
        expect(subject[:duo_sast_fp_detection_enabled]).to be_nil
      end
    end
  end

  describe 'duo_secret_detection_fp_enabled' do
    context 'when project is licensed to use ai_features and feature flag is enabled' do
      before do
        stub_licensed_features(ai_features: true)
        stub_feature_flags(duo_secret_detection_false_positive: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_secret_detection_fp_enabled]).to be_in([true, false])
      end
    end

    context 'when project is licensed to use ai_features but feature flag is disabled' do
      before do
        stub_licensed_features(ai_features: true)
        stub_feature_flags(duo_secret_detection_false_positive: false)
      end

      it 'returns nil' do
        expect(subject[:duo_secret_detection_fp_enabled]).to be_nil
      end
    end

    context 'when project is not licensed to use ai_features' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_features: false)
        stub_feature_flags(duo_secret_detection_false_positive: true)
      end

      it 'returns nil' do
        expect(subject[:duo_secret_detection_fp_enabled]).to be_nil
      end
    end
  end

  describe 'duo_dependency_bump_breaking_changes_enabled' do
    context 'when project is licensed to use ai_features and feature flag is enabled' do
      before do
        stub_licensed_features(ai_features: true)
        stub_feature_flags(enable_dependency_bump_breaking_changes: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_dependency_bump_breaking_changes_enabled]).to be_in([true, false])
      end
    end

    context 'when project is licensed to use ai_features but feature flag is disabled' do
      before do
        stub_licensed_features(ai_features: true)
        stub_feature_flags(enable_dependency_bump_breaking_changes: false)
      end

      it 'returns nil' do
        expect(subject[:duo_dependency_bump_breaking_changes_enabled]).to be_nil
      end
    end

    context 'when project is not licensed to use ai_features' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_features: false)
        stub_feature_flags(enable_dependency_bump_breaking_changes: true)
      end

      it 'returns nil' do
        expect(subject[:duo_dependency_bump_breaking_changes_enabled]).to be_nil
      end
    end
  end

  describe 'duo_sast_vr_workflow_enabled' do
    context 'when project is licensed to use ai_features' do
      before do
        stub_licensed_features(ai_features: true)
      end

      it 'returns a boolean value' do
        expect(subject[:duo_sast_vr_workflow_enabled]).to be_in([true, false])
      end
    end

    context 'when project is not licensed to use ai_features' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(ai_features: false)
      end

      it 'returns nil' do
        expect(subject[:duo_sast_vr_workflow_enabled]).to be_nil
      end
    end
  end

  describe 'web_based_commit_signing_enabled' do
    before do
      stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
    end

    context 'and the repositories_web_based_commit_signing feature is not available' do
      let(:repositories_web_based_commit_signing) { false }

      it 'does not serialize web_based_commit_signing_enabled' do
        expect(subject.keys).not_to include(
          :web_based_commit_signing_enabled
        )
      end
    end

    context 'and the repositories_web_based_commit_signing feature is available' do
      let(:repositories_web_based_commit_signing) { true }

      context 'and user does not have permission for the attribute' do
        let(:options) { { current_user: developer } }

        it 'does not serialize web_based_commit_signing_enabled' do
          expect(subject.keys).not_to include(
            :web_based_commit_signing_enabled
          )
        end
      end

      context 'and user is a maintainer' do
        let(:options) { { current_user: maintainer } }

        it 'returns expected data' do
          expect(subject.keys).to include(
            :web_based_commit_signing_enabled
          )
        end
      end
    end
  end

  describe 'spp_repository_pipeline_access' do
    let_it_be(:project) { create(:project) }

    context 'when feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'returns true by default' do
        expect(subject[:spp_repository_pipeline_access]).to be(true)
      end

      context 'when the setting is disabled' do
        before do
          project.project_setting.update!(spp_repository_pipeline_access: false)
        end

        it 'returns false' do
          expect(subject[:spp_repository_pipeline_access]).to be(false)
        end
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns nil' do
        expect(subject[:spp_repository_pipeline_access]).to be_nil
      end
    end
  end

  describe 'merge_request_title_regex' do
    let_it_be(:project) { create(:project) }

    context 'when feature is available' do
      before do
        stub_licensed_features(merge_request_title_regex_check: true)
        project.update!(merge_request_title_regex: '/test/', merge_request_title_regex_description: 'Must match test')
      end

      it 'returns the merge_request_title_regex' do
        expect(subject[:merge_request_title_regex]).to eq('/test/')
      end

      it 'returns the merge_request_title_regex_description' do
        expect(subject[:merge_request_title_regex_description]).to eq('Must match test')
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(merge_request_title_regex_check: false)
      end

      it 'returns nil for merge_request_title_regex' do
        expect(subject[:merge_request_title_regex]).to be_nil
      end

      it 'returns nil for merge_request_title_regex_description' do
        expect(subject[:merge_request_title_regex_description]).to be_nil
      end
    end
  end
end
