# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildPolicy, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }

  it_behaves_like 'a deployable job policy in EE', :ci_build

  subject { described_class.new(user, build) }

  describe 'troubleshoot_job_with_ai' do
    let(:authorized) { true }
    let(:cloud_connector_user_access) { true }
    let_it_be_with_reload(:project) { create(:project, :private) }
    let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project) }
    let_it_be(:build) { create(:ci_build, pipeline: pipeline) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(ai_features: true, troubleshoot_job: true)
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(
        :resource, :allowed?).and_return(authorized)
      allow(user).to receive(:can?).and_call_original
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
      allow(user).to receive(:can?).with(:access_duo_classic_chat).and_return(true)
      allow(user).to receive(:can?).with(:access_duo_features, build.project).and_return(true)
      allow(user).to receive(:allowed_to_use?).and_return(cloud_connector_user_access)

      allow(project).to receive(:duo_features_enabled).and_return(true)
    end

    context 'when feature is chat authorized' do
      subject { described_class.new(user, build) }

      let(:authorized) { true }

      it { is_expected.to be_allowed(:troubleshoot_job_with_ai) }

      context 'when user cannot read_build' do
        before_all do
          project.add_guest(user)
        end

        before do
          project.update_attribute(:public_builds, false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when the feature is not ai licensed' do
        before do
          stub_licensed_features(ai_features: false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when feature is not licensed for a project' do
        before do
          # Mock the project specifically because there was a bug where we used a global feature check
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(false)
        end

        it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
      end

      context 'when feature is licensed for a project' do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(true)
        end

        it { is_expected.to be_allowed(:troubleshoot_job_with_ai) }
      end
    end

    context 'when feature is not authorized' do
      let(:authorized) { false }

      it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
    end

    context 'when user is nil with public project' do
      before do
        project.visibility_level = Gitlab::VisibilityLevel::PUBLIC
        project.save!
      end

      subject { described_class.new(nil, build) }

      it { is_expected.to be_disallowed(:troubleshoot_job_with_ai) }
    end

    context 'when on .org or .com', :saas do
      using RSpec::Parameterized::TableSyntax
      where(:user_access, :licensed, :allowed) do
        true | true | true
        true | false | false
        false | true | false
        false | false | false
      end

      with_them do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:troubleshoot_job).and_return(licensed)
        end

        let(:cloud_connector_user_access) { user_access }
        let(:policy) { :troubleshoot_job_with_ai }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'admin custom roles', :enable_admin_mode, feature_category: :permissions do
    context 'when user does not have read_build ability' do
      let_it_be(:project) { create(:project, :private, public_builds: false) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
      let_it_be(:build) { create(:ci_build, pipeline: pipeline) }

      it { is_expected.to be_disallowed(:read_build_metadata) }

      context 'when user can read_admin_cicd' do
        before do
          stub_licensed_features(custom_roles: true)
          create(:admin_member_role, :read_admin_cicd, user: user)
        end

        it { is_expected.to be_disallowed(:read_build) }
        it { is_expected.to be_allowed(:read_build_metadata) }
      end
    end
  end
end
