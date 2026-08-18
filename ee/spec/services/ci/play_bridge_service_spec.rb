# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PlayBridgeService, '#execute', feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:downstream_project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: [project, downstream_project]) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let_it_be_with_reload(:job) { create(:ci_bridge, :playable, pipeline: pipeline, downstream: downstream_project) }

  context 'when the user is not authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!).and_raise(::Users::IdentityVerification::Error)
      end
    end

    it 'raises an error' do
      expect do
        described_class.new(project, user).execute(job)
      end.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when the user is authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!)
      end
    end

    it 'returns success' do
      result = described_class.new(project, user).execute(job)

      expect(result).to be_success
    end
  end
end
