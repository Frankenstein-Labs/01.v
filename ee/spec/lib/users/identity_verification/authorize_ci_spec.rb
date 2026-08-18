# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerification::AuthorizeCi, :saas, feature_category: :instance_resiliency do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }

  describe '#authorize_run_jobs!' do
    subject(:authorize) { described_class.new(user: user, project: project).authorize_run_jobs! }

    shared_examples 'logs the failure and raises an exception' do
      before do
        allow(::Gitlab::AppLogger).to receive(:info)
      end

      specify :aggregate_failures do
        expect(::Gitlab::AppLogger)
          .to receive(:info)
          .with(
            message: error_message,
            class: described_class.name,
            project_path: project.full_path,
            user_id: user.id,
            plan: 'free')

        expect { authorize }.to raise_error(::Users::IdentityVerification::Error, error_message)
      end
    end

    context 'when the user is nil' do
      let(:user) { nil }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:authorize_identity_verification!).and_raise(::Users::IdentityVerification::Error)
        end
      end

      it { expect { authorize }.not_to raise_error }
    end

    context 'when shared runners are not enabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(false)
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:authorize_identity_verification!).and_raise(::Users::IdentityVerification::Error)
        end
      end

      it { expect { authorize }.not_to raise_error }
    end

    context 'when identity verification is required' do
      context 'when user identity is verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { expect { authorize }.not_to raise_error }
      end

      context 'when user identity is not verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(false)
        end

        it_behaves_like 'logs the failure and raises an exception' do
          let(:error_message) { 'Identity verification is required in order to run CI jobs' }
        end

        context 'when the application setting is disabled' do
          before do
            stub_application_setting(ci_requires_identity_verification_on_free_plan: false)
          end

          it { expect { authorize }.not_to raise_error }
        end

        context 'when root namespace has a paid plan' do
          let_it_be(:ultimate_group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
          let_it_be(:project) { create(:project, group: ultimate_group) }

          it { expect { authorize }.not_to raise_error }
        end

        context 'when root namespace has purchased compute minutes' do
          before do
            project.namespace.update!(extra_shared_runners_minutes_limit: 100)
            project.namespace.clear_memoization(:ci_minutes_usage)
          end

          it { expect { authorize }.not_to raise_error }
        end
      end
    end
  end

  shared_examples 'verifying identity' do
    context 'when user identity is verified' do
      before do
        allow(user).to receive(:identity_verified?).and_return(true)
      end

      it { is_expected.to be(true) }
    end

    context 'when user identity is not verified' do
      before do
        allow(user).to receive(:identity_verified?).and_return(false)
      end

      it { is_expected.to be(false) }

      context 'when the application setting is disabled' do
        before do
          stub_application_setting(ci_requires_identity_verification_on_free_plan: false)
        end

        it { is_expected.to be(true) }
      end

      context 'when user identity is verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { is_expected.to be(true) }
      end

      context 'when root namespace has a paid plan' do
        let_it_be(:group) { create(:group, :public) }
        let_it_be(:project) { create(:project, group: group) }
        let(:plan_name) { :ultimate_plan }

        before do
          create(:gitlab_subscription, namespace: group, hosted_plan: create(plan_name), trial: false)
        end

        it { is_expected.to be(true) }

        context "with OSS plan" do
          let(:plan_name) { :opensource_plan }

          context 'with id_check_for_oss feature flag enabled' do
            it { is_expected.to be(false) }
          end

          context 'with id_check_for_oss feature flag disabled' do
            before do
              stub_feature_flags(id_check_for_oss: false)
            end

            it { is_expected.to be(true) }
          end
        end
      end

      context 'when root namespace has purchased compute minutes' do
        before do
          project.namespace.update!(extra_shared_runners_minutes_limit: 100)
          project.namespace.clear_memoization(:ci_minutes_usage)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#user_can_run_jobs?' do
    subject { described_class.new(user: user, project: project).user_can_run_jobs? }

    context 'when project shared runners are disabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(false)
      end

      it { is_expected.to be(true) }
    end

    context 'when project shared runners enabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(true)
      end

      it_behaves_like 'verifying identity'
    end
  end

  describe '#user_can_enable_shared_runners?' do
    subject { described_class.new(user: user, project: project).user_can_enable_shared_runners? }

    it_behaves_like 'verifying identity'
  end
end
