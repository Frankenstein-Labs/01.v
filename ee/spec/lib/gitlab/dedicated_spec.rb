# frozen_string_literal: true

RSpec.describe Gitlab::Dedicated, feature_category: :acquisition do
  describe '.feature_available?' do
    using RSpec::Parameterized::TableSyntax

    context 'with an existing feature' do
      let(:feature) { :skip_ultimate_trial_experience }

      before do
        stub_const("#{described_class}::FEATURES", [feature])
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(dedicated?)
      end

      subject(:feature_available?) { described_class.feature_available?(feature) } # rubocop:disable Gitlab/FeatureAvailableUsage -- False positive due to same name of method

      context 'when on Dedicated' do
        let(:dedicated?) { true }

        it { is_expected.to be true }
      end

      context 'when not on Dedicated' do
        let(:dedicated?) { false }

        it { is_expected.to be false }
      end
    end

    context 'with an invalid feature' do
      let(:feature) { :_bogus_feature_ }

      subject(:feature_available?) { described_class.feature_available?(feature) } # rubocop:disable Gitlab/FeatureAvailableUsage -- False positive due to same name of method

      it 'raises an error' do
        expect { feature_available? }.to raise_error(described_class::MissingFeatureError, 'Feature does not exist')
      end
    end
  end

  context 'with dedicated feature file check' do
    where(
      case_names: ->(feature) { described_class.feature_file_path(feature) },
      feature: described_class::FEATURES
    )

    with_them do
      it 'exists for the defined_feature' do
        expect(File.exist?(Gitlab::Dedicated.feature_file_path(feature))).to be_truthy
      end
    end
  end

  describe '.feature_file_path' do
    subject(:feature_file_path) { described_class.feature_file_path(feature) }

    let(:feature) { :some_feature }

    it { is_expected.to eq(Rails.root.join(described_class::CONFIG_FILE_ROOT, "#{feature}.yml")) }
  end
end
