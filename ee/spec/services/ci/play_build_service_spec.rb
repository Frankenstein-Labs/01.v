# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PlayBuildService, '#execute', feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  context 'when user does not have access to the environment' do
    let_it_be(:environment) { create(:environment, project: project, name: 'production') }
    let_it_be(:job, freeze: false) do
      create(:ci_build, :manual, pipeline: pipeline, environment: environment.name, project: project)
    end

    let!(:protected_environment) { create(:protected_environment, name: environment.name, project: project) }

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(protected_environments: true)
    end

    it 'raises an error' do
      expect do
        described_class.new(current_user: user, build: job).execute
      end.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when user has access to the environment' do
    let_it_be(:environment) { create(:environment, project: project, name: 'staging') }
    let_it_be(:job, freeze: false) do
      create(:ci_build, :manual, pipeline: pipeline, environment: environment.name, project: project)
    end

    let!(:protected_environment) do
      env = create(:protected_environment, name: environment.name, project: project)
      env.deploy_access_levels.create!(user: user)
      env
    end

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(protected_environments: true)
    end

    it 'enqueues the build' do
      result = described_class.new(current_user: user, build: job).execute

      expect(result).to be_success
      expect(result.payload[:job]).to be_pending
    end
  end

  context 'when the user is not authorized to run jobs' do
    let_it_be_with_reload(:job) { create(:ci_build, :manual, pipeline: pipeline) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!).and_raise(::Users::IdentityVerification::Error)
      end
    end

    it 'raises an error' do
      expect do
        described_class.new(current_user: user, build: job).execute
      end.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when the user is authorized to run jobs' do
    let_it_be_with_reload(:job) { create(:ci_build, :manual, pipeline: pipeline) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!)
      end
    end

    it 'returns success' do
      result = described_class.new(current_user: user, build: job).execute

      expect(result).to be_success
    end
  end
end
