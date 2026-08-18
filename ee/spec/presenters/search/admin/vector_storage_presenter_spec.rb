# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Admin::VectorStoragePresenter, feature_category: :global_search do
  let(:elasticsearch_options) { { 'url' => 'http://localhost:9200', 'username' => 'admin' } }
  let(:opensearch_options) { { 'url' => 'http://localhost:9202', 'aws' => true, 'aws_region' => 'us-east-1' } }

  def build_presenter(**overrides)
    described_class.new(
      using_advanced_search: false,
      custom_active: true,
      inputs_disabled: false,
      selected_adapter_name: 'elasticsearch',
      existing_adapter_name: 'elasticsearch',
      adapter_configs: {
        'elasticsearch' => {
          'options' => elasticsearch_options,
          'password_value' => '*****',
          'aws_secret_value' => nil
        },
        'opensearch' => {
          'options' => opensearch_options,
          'password_value' => '*****',
          'aws_secret_value' => '*****'
        }
      },
      **overrides
    )
  end

  subject(:presenter) { build_presenter }

  describe '#adapter_section' do
    context 'when elasticsearch is selected and active' do
      it 'returns not hidden for elasticsearch' do
        expect(presenter.adapter_section('elasticsearch').hidden_class).to eq('')
      end

      it 'returns hidden for opensearch' do
        expect(presenter.adapter_section('opensearch').hidden_class).to eq('gl-hidden')
      end

      it 'marks elasticsearch as in use' do
        expect(presenter.adapter_section('elasticsearch').in_use).to be true
      end

      it 'does not mark opensearch as in use' do
        expect(presenter.adapter_section('opensearch').in_use).to be false
      end

      it 'returns the correct options for each adapter', :aggregate_failures do
        expect(presenter.adapter_section('elasticsearch').options).to eq(elasticsearch_options)
        expect(presenter.adapter_section('opensearch').options).to eq(opensearch_options)
      end

      it 'returns the password value for elasticsearch' do
        expect(presenter.adapter_section('elasticsearch').password_value).to eq('*****')
      end

      it 'returns nil aws_secret_value for elasticsearch' do
        expect(presenter.adapter_section('elasticsearch').aws_secret_value).to be_nil
      end

      it 'returns the password value for opensearch' do
        expect(presenter.adapter_section('opensearch').password_value).to eq('*****')
      end

      it 'returns aws_secret_value for opensearch' do
        expect(presenter.adapter_section('opensearch').aws_secret_value).to eq('*****')
      end
    end

    context 'when opensearch is selected' do
      subject(:presenter) do
        build_presenter(
          selected_adapter_name: 'opensearch',
          existing_adapter_name: 'opensearch',
          adapter_configs: {
            'elasticsearch' => {
              'options' => elasticsearch_options, 'password_value' => '*****', 'aws_secret_value' => nil
            },
            'opensearch' => {
              'options' => opensearch_options, 'password_value' => '*****', 'aws_secret_value' => '*****'
            }
          }
        )
      end

      it 'returns hidden for elasticsearch' do
        expect(presenter.adapter_section('elasticsearch').hidden_class).to eq('gl-hidden')
      end

      it 'returns not hidden for opensearch' do
        expect(presenter.adapter_section('opensearch').hidden_class).to eq('')
      end

      it 'returns the password value for opensearch' do
        expect(presenter.adapter_section('opensearch').password_value).to eq('*****')
      end
    end

    context 'when opensearch aws is submitted as a string from the form' do
      context 'when aws is "1"' do
        let(:opensearch_options) { super().merge('aws' => '1') }

        it 'coerces to true' do
          expect(presenter.adapter_section('opensearch').options['aws']).to be true
        end
      end

      context 'when aws is "0"' do
        let(:opensearch_options) { super().merge('aws' => '0') }

        it 'coerces to false' do
          expect(presenter.adapter_section('opensearch').options['aws']).to be false
        end
      end
    end

    context 'when no adapter is selected' do
      subject(:presenter) do
        build_presenter(
          custom_active: false,
          selected_adapter_name: nil,
          existing_adapter_name: nil,
          adapter_configs: {
            'elasticsearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil },
            'opensearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil }
          }
        )
      end

      it 'does not mark either adapter as in use', :aggregate_failures do
        expect(presenter.adapter_section('elasticsearch').in_use).to be false
        expect(presenter.adapter_section('opensearch').in_use).to be false
      end

      it 'elasticsearch is not hidden when no adapter selected' do
        expect(presenter.adapter_section('elasticsearch').hidden_class).to eq('')
      end
    end

    context 'when inputs are disabled' do
      subject(:presenter) do
        build_presenter(
          using_advanced_search: true,
          custom_active: false,
          inputs_disabled: true,
          selected_adapter_name: nil,
          existing_adapter_name: nil,
          adapter_configs: {
            'elasticsearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil },
            'opensearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil }
          }
        )
      end

      it 'propagates inputs_disabled to both sections', :aggregate_failures do
        expect(presenter.adapter_section('elasticsearch').inputs_disabled).to be true
        expect(presenter.adapter_section('opensearch').inputs_disabled).to be true
      end
    end

    context 'when postgresql is selected and active' do
      let(:postgresql_options) do
        { 'host' => 'db.example.com', 'port' => '5432', 'database' => 'gitlabhq', 'user' => 'gitlab' }
      end

      subject(:presenter) do
        build_presenter(
          selected_adapter_name: 'postgresql',
          existing_adapter_name: 'postgresql',
          adapter_configs: {
            'elasticsearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil },
            'opensearch' => { 'options' => {}, 'password_value' => nil, 'aws_secret_value' => nil },
            'postgresql' => {
              'options' => postgresql_options,
              'password_value' => '*****',
              'aws_secret_value' => nil
            }
          }
        )
      end

      it 'returns not hidden for postgresql' do
        expect(presenter.adapter_section('postgresql').hidden_class).to eq('')
      end

      it 'returns hidden for elasticsearch and opensearch', :aggregate_failures do
        expect(presenter.adapter_section('elasticsearch').hidden_class).to eq('gl-hidden')
        expect(presenter.adapter_section('opensearch').hidden_class).to eq('gl-hidden')
      end

      it 'marks postgresql as in use' do
        expect(presenter.adapter_section('postgresql').in_use).to be true
      end

      it 'returns the correct options for postgresql' do
        expect(presenter.adapter_section('postgresql').options).to eq(postgresql_options)
      end

      it 'returns the password value for postgresql' do
        expect(presenter.adapter_section('postgresql').password_value).to eq('*****')
      end

      it 'returns nil aws_secret_value for postgresql' do
        expect(presenter.adapter_section('postgresql').aws_secret_value).to be_nil
      end
    end

    context 'when an adapter not in the config is requested' do
      it 'returns hidden with no credentials', :aggregate_failures do
        section = presenter.adapter_section('unknown_adapter')
        expect(section.hidden_class).to eq('gl-hidden')
        expect(section.in_use).to be false
        expect(section.options).to eq({})
        expect(section.password_value).to be_nil
        expect(section.aws_secret_value).to be_nil
      end
    end
  end

  describe '#advanced_search_configured?' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(true)
    end

    context 'when license is available and indexing is enabled' do
      before do
        stub_licensed_features(elastic_search: true)
      end

      it 'returns true' do
        expect(build_presenter.advanced_search_configured?).to be true
      end
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(elastic_search: false)
      end

      it 'returns false' do
        expect(build_presenter.advanced_search_configured?).to be false
      end
    end

    context 'when elasticsearch indexing is disabled' do
      before do
        stub_licensed_features(elastic_search: true)
        allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(false)
      end

      it 'returns false' do
        expect(build_presenter.advanced_search_configured?).to be false
      end
    end
  end

  describe '#effective_adapter_name' do
    it 'returns the selected adapter when set' do
      expect(build_presenter(selected_adapter_name: 'opensearch').effective_adapter_name).to eq('opensearch')
    end

    it 'defaults to elasticsearch when none is selected' do
      expect(build_presenter(selected_adapter_name: nil).effective_adapter_name).to eq('elasticsearch')
    end
  end
end
