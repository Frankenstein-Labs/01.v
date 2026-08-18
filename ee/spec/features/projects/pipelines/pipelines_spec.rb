# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipelines', :js, feature_category: :continuous_integration do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }

  before do
    sign_in(user)

    project.add_developer(user)
  end

  describe 'GET /:project/-/pipelines' do
    describe 'when namespace is in read-only mode' do
      before do
        # Trigger read-only mode via storage limit to avoid association loading issues with direct Namespace stubbing
        allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
          allow(size_checker).to receive(:above_size_limit?).and_return(true)
        end
      end

      let!(:pipeline) { create(:ci_pipeline, project: project, user: user) }

      it 'does not render New pipeline link' do
        visit project_pipelines_path(project)
        wait_for_requests
        expect(page).to have_content('Show Pipeline ID')
        expect(page).not_to have_link('New pipeline')
      end
    end
  end

  describe 'GET /:project/-/pipelines/new' do
    describe 'when namespace is in read-only mode' do
      it 'renders 404' do
        allow_next_found_instance_of(Namespace) do |instance|
          allow(instance).to receive(:read_only?).and_return(true)
        end

        visit new_project_pipeline_path(project)
        expect(page).to have_content('Page not found')
      end
    end
  end

  describe 'POST /:project/-/pipelines' do
    describe 'identity verification requirement', :js, :saas do
      include IdentityVerificationHelpers

      let_it_be_with_reload(:user) { create(:user, :identity_verification_eligible) }

      before do
        stub_saas_features(identity_verification: true)
        allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(true)

        stub_ci_pipeline_to_return_yaml_file

        visit new_project_pipeline_path(project)
      end

      subject(:run_pipeline) do
        find_by_testid('run-pipeline-button', text: 'New pipeline').click

        wait_for_requests
      end

      it 'prompts the user to verify their account' do
        expect { run_pipeline }.not_to change { Ci::Pipeline.count }

        expect(page).to have_content('Before you can run pipelines, we need to verify your account.')

        click_on 'Verify my account'

        wait_for_requests

        expect_to_see_identity_verification_page

        solve_arkose_verify_challenge

        verify_phone_number

        wait_for_requests

        run_pipeline

        expect(page).not_to have_content('Before you can run pipelines, we need to verify your account.')
      end

      context 'when user is a member of a paid namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        end

        it 'does not prompt the user to verify their account' do
          expect { run_pipeline }.to change { Ci::Pipeline.count }.by(1)

          expect(page).not_to have_content('Before you can run pipelines, we need to verify your account.')
        end
      end
    end
  end
end
