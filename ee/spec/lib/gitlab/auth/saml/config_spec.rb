# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Saml::Config, feature_category: :system_access do
  include LoginHelpers
  let(:config) { described_class.new }

  describe '#group_sync_enabled?' do
    subject { config.group_sync_enabled? }

    it { is_expected.to be(false) }

    context 'when SAML is enabled' do
      before do
        stub_basic_saml_config
      end

      it { is_expected.to be(false) }

      context 'when the group attribute is configured' do
        before do
          allow(config).to receive(:groups).and_return(['Groups'])
        end

        it { is_expected.to be(false) }

        context 'when the saml_group_sync feature is licensed' do
          before do
            stub_licensed_features(saml_group_sync: true)
          end

          it { is_expected.to be(true) }
        end
      end
    end
  end

  shared_examples 'Microsoft Group Sync enabled?' do
    using RSpec::Parameterized::TableSyntax

    where(:saml_enabled?, :feature_licensed?, :expect_microsoft_group_sync_enabled?) do
      false | false  | false
      true  | false  | false
      false | true   | false
      true  | true   | true
    end

    with_them do
      before do
        stub_basic_saml_config if saml_enabled?
        stub_licensed_features(microsoft_group_sync: feature_licensed?)
      end

      it { is_expected.to eq(expect_microsoft_group_sync_enabled?) }
    end
  end

  describe '#microsoft_group_sync_enabled?' do
    subject { config.microsoft_group_sync_enabled? }

    context 'when groups attribute is configured for the provider' do
      before do
        allow(config).to receive(:groups).and_return(['Groups'])
      end

      it_behaves_like 'Microsoft Group Sync enabled?'
    end

    context 'when groups attribute is not configured for the provider' do
      before do
        stub_basic_saml_config
        stub_licensed_features(microsoft_group_sync: true)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.microsoft_group_sync_enabled?' do
    subject { described_class.microsoft_group_sync_enabled? }

    it_behaves_like 'Microsoft Group Sync enabled?'
  end
end
