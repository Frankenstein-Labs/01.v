# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ProjectCancellationRestriction, feature_category: :continuous_integration do
  let(:project) { create_default(:project) }
  let(:cancellation_restriction) { described_class.new(project) }
  let(:settings) { project.ci_cd_settings }
  let(:roles) { settings.class.restrict_pipeline_cancellation_roles }

  describe '#maintainers_only_allowed?' do
    subject { cancellation_restriction.maintainers_only_allowed? }

    context 'when no project' do
      let(:project) { nil }

      it { is_expected.to be false }
    end

    context 'when no ci settings' do
      before do
        allow(project).to receive(:ci_cd_settings).and_return(nil)
      end

      it { is_expected.to be false }
    end

    context 'when the licensed feature is enabled' do
      before do
        stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
      end

      it 'returns true if maintainers are the only ones allowed to cancel' do
        settings.update!(restrict_pipeline_cancellation_role: roles[:maintainer])

        is_expected.to be true
      end

      [:no_one, :developer].each do |role|
        it "returns false if #{role} is allowed to cancel" do
          settings.update!(restrict_pipeline_cancellation_role: role)

          is_expected.to be false
        end
      end
    end

    context 'when the licensed_features is disabled' do
      it { is_expected.to be false }
    end
  end

  describe '#no_one_allowed?' do
    subject { cancellation_restriction.no_one_allowed? }

    context 'when no project' do
      let(:project) { nil }

      it { is_expected.to be false }
    end

    context 'when no ci settings' do
      before do
        allow(project).to receive(:ci_cd_settings).and_return(nil)
      end

      it { is_expected.to be false }
    end

    context 'when the licensed feature is enabled' do
      before do
        stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
      end

      it 'returns true if no one is allowed to cancel' do
        settings.update!(restrict_pipeline_cancellation_role: roles[:no_one])

        is_expected.to be true
      end

      [:maintainer, :developer].each do |role|
        it "returns false if #{role} is allowed to cancel" do
          settings.update!(restrict_pipeline_cancellation_role: role)

          is_expected.to be false
        end
      end
    end

    context 'when the licensed_features is disabled' do
      it { is_expected.to be false }
    end
  end

  describe '#feature_available?' do
    subject { cancellation_restriction.feature_available? }

    context 'when no project' do
      let(:project) { nil }

      it { is_expected.to be false }
    end

    context 'when no ci settings' do
      before do
        allow(project).to receive(:ci_cd_settings).and_return(nil)
      end

      it { is_expected.to be false }
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
      end

      it { is_expected.to be true }
    end

    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(ci_pipeline_cancellation_restrictions: false)
      end

      it { is_expected.to be false }
    end
  end
end
