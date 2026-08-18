# frozen_string_literal: true

RSpec.shared_examples 'handling google cloud client common errors' do |client_method:|
  shared_examples 'transforming the error' do |message:, from_klass:, to_klass:|
    it "translates the error from #{from_klass} to #{to_klass}" do
      expect(client_double).to receive(client_method).and_raise(from_klass, message)

      expect { subject }.to raise_error(to_klass, message)
    end
  end

  it_behaves_like 'transforming the error',
    message: "test #{described_class::GOOGLE_CLOUD_SUBJECT_TOKEN_ERROR_MESSAGE} test",
    from_klass: RuntimeError,
    to_klass: ::GoogleCloud::AuthenticationError

  it_behaves_like 'transforming the error',
    message: "test #{described_class::GOOGLE_CLOUD_TOKEN_EXCHANGE_ERROR_MESSAGE} test",
    from_klass: RuntimeError,
    to_klass: ::GoogleCloud::AuthenticationError

  it_behaves_like 'transforming the error',
    message: "test",
    from_klass: RuntimeError,
    to_klass: RuntimeError

  it_behaves_like 'transforming the error',
    message: "test",
    from_klass: ::Google::Cloud::Error,
    to_klass: ::GoogleCloud::ApiError
end

RSpec.shared_examples 'handling google cloud client common validations' do
  before do
    stub_saas_features(google_cloud_support: true)
  end

  shared_examples 'raising an error with' do |klass, message|
    it "raises #{klass} error" do
      expect { client }.to raise_error(klass, message)
    end
  end

  context 'with a nil integration' do
    let(:wlif_integration) { nil }

    it_behaves_like 'raising an error with', ArgumentError, described_class::BLANK_PARAMETERS_ERROR_MESSAGE
  end

  context 'with a disabled integration' do
    before do
      wlif_integration.update_column(:active, false)
    end

    it_behaves_like 'raising an error with', ArgumentError, described_class::DISABLED_INTEGRATION
  end

  context 'with an integration of the wrong class' do
    let_it_be(:wlif_integration) do
      build(:google_cloud_platform_artifact_registry_integration, project: project)
    end

    it_behaves_like 'raising an error with', ArgumentError, described_class::WRONG_INTEGRATION_CLASS
  end

  context 'with a nil user' do
    let(:user) { nil }

    it_behaves_like 'raising an error with', ArgumentError, described_class::BLANK_PARAMETERS_ERROR_MESSAGE
  end

  context 'when not on saas' do
    before do
      stub_saas_features(google_cloud_support: false)
    end

    it_behaves_like 'raising an error with', RuntimeError, described_class::SAAS_ONLY_ERROR_MESSAGE
  end
end
