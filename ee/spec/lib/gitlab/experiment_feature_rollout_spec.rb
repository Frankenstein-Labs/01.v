# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ExperimentFeatureRollout, :experiment, feature_category: :acquisition do
  subject(:experiment_instance) { described_class.new(experiment('namespaced/stub')) }

  before do
    stub_const('Namespaced::StubExperiment', Class.new(ApplicationExperiment))
  end

  describe "#enabled?" do
    let(:experimentation_enabled) { true }

    before do
      stub_saas_features(experimentation: experimentation_enabled)
      stub_feature_flags(gitlab_experiment: true)
      allow(experiment_instance).to receive(:feature_flag_defined?).and_return(true)
      allow(experiment_instance)
        .to receive(:feature_flag_instance).and_return(instance_double('Flipper::Feature', state: :on))
    end

    context 'when saas feature is available' do
      it { is_expected.to be_enabled }

      it "isn't enabled if the feature definition doesn't exist" do
        expect(experiment_instance).to receive(:feature_flag_defined?).and_return(false)

        expect(experiment_instance).not_to be_enabled
      end

      it "isn't enabled if the feature flag state is :off" do
        expect(experiment_instance)
          .to receive(:feature_flag_instance).and_return(instance_double('Flipper::Feature', state: :off))

        expect(experiment_instance).not_to be_enabled
      end

      it "isn't enabled if the gitlab_experiment feature flag is false" do
        stub_feature_flags(gitlab_experiment: false)

        expect(experiment_instance).not_to be_enabled
      end
    end

    context 'when saas feature is not available' do
      let(:experimentation_enabled) { false }

      it "is not enabled" do
        expect(experiment_instance).not_to be_enabled
      end
    end
  end
end
