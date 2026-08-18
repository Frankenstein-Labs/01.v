# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ProcessBuildService, '#execute', feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:environment) { create(:environment, project: project, name: 'production') }
  let_it_be_with_reload(:protected_environment) { create(:protected_environment, name: environment.name, project: project) }

  let(:build_traits) { %i[created prepare_staging] }
  let(:build_when) { :on_success }
  let(:ci_build) { create(:ci_build, *build_traits, environment: environment.name, user: user, project: project, when: build_when) }

  subject { described_class.new(project, user).execute(ci_build, 'success') }

  before do
    stub_licensed_features(protected_environments: feature_available)

    protected_environment
  end

  context 'when related to a protected environment' do
    context 'when Protected Environments feature is not available on project' do
      let(:feature_available) { false }

      it 'enqueues the build' do
        subject

        expect(ci_build.pending?).to be_truthy
      end
    end

    context 'when Protected Environments feature is available on project' do
      let(:feature_available) { true }

      context 'when user does not have access to the environment' do
        it 'fails the build' do
          allow(Deployments::LinkMergeRequestWorker).to receive(:perform_async)
          allow(Deployments::HooksWorker).to receive(:perform_async)
          subject

          expect(ci_build.failed?).to be_truthy
          expect(ci_build.failure_reason).to eq('protected_environment_failure')
        end

        context 'and the build is manual' do
          let(:build_traits) { %i[created actionable] }
          let(:build_when) { :manual }

          it 'actionizes the build' do
            expect { subject }.to change { ci_build.status }.from('created').to('manual')
          end
        end
      end

      context 'when user has access to the environment' do
        before do
          protected_environment.deploy_access_levels.create!(user: user)
        end

        it 'enqueues the build' do
          subject

          expect(ci_build.pending?).to be_truthy
        end

        shared_examples_for 'blocking deployment job' do
          it 'does not block the job by default' do
            expect { subject }.to change { ci_build.status }.from('created').to('pending')
          end

          context 'when the prevent_blocking_non_deployment_jobs feature flag is disabled' do
            before do
              stub_feature_flags(prevent_blocking_non_deployment_jobs: false)
            end

            it 'makes the build a manual action' do
              expect { subject }.to change { ci_build.status }.from('created').to('manual')
            end
          end

          context 'and the build has a deployment' do
            shared_examples_for 'blocked deployment' do
              it 'blocks the deployment' do
                expect { subject }.to change { deployment.reload.status }.from('created').to('blocked')
              end

              it 'makes the build a manual action' do
                expect { subject }.to change { ci_build.status }.from('created').to('manual')
              end
            end

            let(:build_traits) { %i[created deploy_to_production] }
            let!(:deployment) { create(:deployment, deployable: ci_build, environment: environment, user: user, project: project) }

            include_examples 'blocked deployment'

            it 'sets manual to build.when' do
              expect { subject }.to change { ci_build.reload.when }.to('manual')
            end

            context 'and the build is schedulable' do
              let(:build_traits) { %i[created schedulable deploy_to_production] }

              include_examples 'blocked deployment'
            end

            context 'and the build is actionable' do
              let(:build_traits) { %i[created actionable deploy_to_production] }

              include_examples 'blocked deployment'
            end
          end
        end

        context 'with multi access levels' do
          let!(:approval_rule) do
            create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment)
          end

          it_behaves_like 'blocking deployment job'
        end
      end
    end
  end
end
