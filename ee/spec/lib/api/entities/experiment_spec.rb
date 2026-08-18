# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Experiment, feature_category: :acquisition do
  let(:experiment) { Feature::Definition.get(:null_hypothesis) }
  let(:entity) { described_class.new(experiment) }

  subject(:entity_json) { entity.as_json }

  it "exposes experiment with definition and current status" do
    is_expected.to match(
      key: "null_hypothesis",
      context: [:user],
      definition: {
        name: 'null_hypothesis',
        feature_issue_url: nil,
        introduced_by_url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45840',
        rollout_issue_url: nil,
        intended_to_rollout_by: nil,
        milestone: '13.7',
        type: 'experiment',
        group: 'group::acquisition',
        default_enabled: false,
        log_state_changes: nil
      },
      current_status: {
        state: :off,
        gates: [
          {
            key: :boolean,
            value: false
          },
          {
            key: :expression,
            value: nil
          }
        ]
      }
    )
  end

  it "understands conditional state and what that means" do
    Feature.enable_percentage_of_time(:null_hypothesis, 1)

    expect(entity_json[:current_status]).to match({
      state: :conditional,
      gates: [
        {
          key: :boolean,
          value: false
        },
        {
          key: :expression,
          value: nil
        },
        {
          key: :percentage_of_time,
          value: 1
        }
      ]
    })
  end

  it "understands state and what that means for if its enabled or not" do
    Feature.enable_percentage_of_time(:null_hypothesis, 100)

    expect(entity_json[:current_status]).to match({
      state: :on,
      gates: [
        {
          key: :boolean,
          value: false
        },
        {
          key: :expression,
          value: nil
        },
        {
          key: :percentage_of_time,
          value: 100
        }
      ]
    })
  end

  it "truncates the name since some experiments include extra data in their feature flag name" do
    allow(experiment).to receive(:attributes).and_return({ name: 'foo_experiment_percentage' })

    expect(entity_json).to include(
      key: 'foo'
    )
  end

  it "resolves the experiment class after truncating the name, so context is still exposed" do
    allow(experiment).to receive(:attributes).and_return({ name: 'null_hypothesis_experiment_percentage' })

    expect(entity_json).to include(
      key: 'null_hypothesis',
      context: [:user]
    )
  end

  it "exposes multiple declared context keys, preserving their order" do
    allow(NullHypothesisExperiment).to receive(:context_keys).and_return(%i[user namespace])

    expect(entity_json[:context]).to eq(%i[user namespace])
  end

  it "exposes an empty context when the experiment does not declare context keys" do
    allow(NullHypothesisExperiment).to receive(:context_keys).and_raise(Gitlab::AbstractMethodError)

    expect(entity_json[:context]).to eq([])
  end

  it "exposes an empty context when the experiment has no registered class" do
    allow(ApplicationExperiment).to receive(:constantize).and_raise(Gitlab::Experiment::UnregisteredExperiment)

    expect(entity_json[:context]).to eq([])
  end
end
