# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::Completion, feature_category: :onboarding do
  let(:completed_actions) { {} }
  let(:project) { build(:project, namespace: namespace) }
  let!(:onboarding_progress) { create(:onboarding_progress, namespace: namespace, **completed_actions) }

  let_it_be(:namespace) { create(:namespace) }

  describe '#percentage' do
    let(:tracked_action_columns) do
      described_class::ACTION_PATHS.map do |key|
        ::Onboarding::Progress.column_name(key)
      end
    end

    subject(:percentage) { described_class.new(project).percentage }

    context 'when no onboarding_progress exists' do
      subject(:percentage) { described_class.new(build(:project)).percentage }

      it { is_expected.to eq(0) }
    end

    context 'when no action has been completed' do
      let(:repository_created_percentage) { 8 }

      it 'returns the created repository action as always completed' do
        is_expected.to eq(repository_created_percentage)
      end
    end

    context 'when all tracked actions have been completed' do
      let(:completed_actions) { tracked_action_columns.index_with { Time.current } }

      it { is_expected.to eq(100) }
    end
  end

  describe '#get_started_percentage' do
    let(:get_started_action_columns) do
      described_class::ACTION_PATHS.filter_map do |key|
        next if key == :created

        ::Onboarding::Progress.column_name(key)
      end
    end

    subject(:get_started_percentage) { described_class.new(project).get_started_percentage }

    context 'when no onboarding_progress exists' do
      subject(:get_started_percentage) { described_class.new(build(:project)).get_started_percentage }

      it { is_expected.to eq(0) }
    end

    context 'when no get started actions have been completed' do
      it 'returns 0 percentage' do
        is_expected.to eq(0)
      end
    end

    context 'when some get started actions have been completed' do
      let(:completed_actions) do
        {
          duo_seat_assigned_at: Time.current,
          pipeline_created_at: Time.current,
          trial_started_at: Time.current
        }
      end

      it 'returns the correct percentage based on completed actions' do
        total_get_started_actions = get_started_action_columns.count
        completed_get_started_actions = 3
        expected_percentage = (completed_get_started_actions.to_f / total_get_started_actions * 100).round

        is_expected.to eq(expected_percentage)
      end
    end

    context 'when all get started actions have been completed' do
      let(:completed_actions) { get_started_action_columns.index_with { Time.current } }

      it { is_expected.to eq(100) }
    end
  end

  describe '#completed?' do
    subject(:completed?) { described_class.new(project).completed?(column) }

    let(:column) { :code_added_at }
    let(:completed_actions) { { code_added_at: code_added_at_timestamp } }

    context 'when the action has been completed' do
      let(:code_added_at_timestamp) { Time.current }

      it { is_expected.to be(true) }

      context 'when onboarding_progress is provided to initializer' do
        let(:column) { :code_added_at }
        let(:completed_actions) { { code_added_at: Time.current } }
        let(:onboarding_progress) { build(:onboarding_progress, **completed_actions) }

        subject(:completed?) do
          described_class.new(project, onboarding_progress: onboarding_progress).completed?(column)
        end

        it { is_expected.to be(true) }
      end
    end

    context 'when the action has not been completed' do
      let(:code_added_at_timestamp) { nil }

      it { is_expected.to be(false) }
    end
  end
end
