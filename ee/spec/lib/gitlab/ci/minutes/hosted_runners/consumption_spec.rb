# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Minutes::HostedRunners::Consumption, feature_category: :hosted_runners do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_refind(:runner) { create(:ci_runner) }
  let(:pipeline) { build_stubbed(:ci_pipeline, project: project) }
  let(:duration) { 120 }

  let(:consumption) do
    described_class.new(pipeline: pipeline, runner_matcher: runner.runner_matcher, duration: duration)
  end

  describe '#amount' do
    subject(:amount) { consumption.amount }

    where(:visibility_level, :public_cost_factor, :private_cost_factor, :result) do
      Gitlab::VisibilityLevel::PRIVATE  | 1.0 | 2.0 | 4.0
      Gitlab::VisibilityLevel::INTERNAL | 1.0 | 2.0 | 4.0
      Gitlab::VisibilityLevel::INTERNAL | 1.0 | 1.5 | 3.0
      Gitlab::VisibilityLevel::PUBLIC   | 2.0 | 1.0 | 4.0
      Gitlab::VisibilityLevel::PUBLIC   | 1.0 | 1.0 | 2.0
      Gitlab::VisibilityLevel::PUBLIC   | 0.5 | 1.0 | 1.0
    end

    with_them do
      let(:expected_cost_factor) do
        next public_cost_factor if visibility_level == Gitlab::VisibilityLevel::PUBLIC

        private_cost_factor
      end

      before do
        project.update!(visibility_level: visibility_level)

        runner.update!(
          public_projects_minutes_cost_factor: public_cost_factor,
          private_projects_minutes_cost_factor: private_cost_factor)

        allow(Gitlab::AppLogger).to receive(:info)
      end

      it 'returns the expected consumption amount' do
        expect(amount).to eq(result)
      end

      it 'logs the cost factor' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            cost_factor: expected_cost_factor,
            project_path: project.full_path,
            pipeline_id: pipeline.id,
            class: described_class.name
          )
        )

        amount
      end
    end
  end
end
