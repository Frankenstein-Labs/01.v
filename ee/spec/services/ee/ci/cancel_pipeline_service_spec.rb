# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CancelPipelineService, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { project.owner }

  describe '#force_execute' do
    context 'when preloading relations for security builds' do
      let(:pipeline1) { create(:ci_pipeline, :created, project: project) }
      let(:pipeline2) { create(:ci_pipeline, :created, project: project) }

      before do
        create(:ee_ci_build, :pending, :sast, pipeline: pipeline1)

        create(:ee_ci_build, :pending, :sast, pipeline: pipeline2)
        create(:ee_ci_build, :pending, :sast, pipeline: pipeline2)
      end

      it 'preloads relations for each security build to avoid N+1 queries' do
        control1 = ActiveRecord::QueryRecorder.new do
          described_class.new(pipeline: pipeline1, current_user: current_user).force_execute
        end

        control2 = ActiveRecord::QueryRecorder.new do
          described_class.new(pipeline: pipeline2, current_user: current_user).force_execute
        end

        extra_update_queries = 6 # state transition, queue pop, security scan initialization
        extra_commit_queries = 2

        expect(control2.count).to be <= (control1.count + extra_update_queries + extra_commit_queries)
      end
    end
  end
end
