# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Validate::AfterConfig, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  let(:pipeline) do
    build(:ci_pipeline, project: project)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command
      .new(project: project, current_user: user, origin_ref: ref, save_incompleted: true)
  end

  let(:step) { described_class.new(pipeline, command) }
  let(:ref) { 'master' }

  describe '#perform!' do
    context 'when the user is not authorized' do
      before do
        allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
          allow(instance).to receive(:authorize_run_jobs!).and_raise(
            ::Users::IdentityVerification::Error, 'authorization error')
        end
      end

      it 'breaks the chain with an error' do
        step.perform!

        expect(step.break?).to be_truthy
        expect(pipeline.errors.to_a).to include('authorization error')
        expect(pipeline.failure_reason).to eq('user_not_verified')
        expect(pipeline).to be_persisted # when passing a failure reason the pipeline is persisted
      end
    end

    context 'when the user is authorized' do
      before do
        allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
          allow(instance).to receive(:authorize_run_jobs!)
        end
      end

      it 'succeeds the step' do
        step.perform!

        expect(step.break?).to be_falsey
        expect(pipeline.errors).to be_empty
      end
    end
  end
end
