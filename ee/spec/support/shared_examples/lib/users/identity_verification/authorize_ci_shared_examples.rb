# frozen_string_literal: true

RSpec.shared_examples 'authorizing CI jobs' do
  context 'when the user is not authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!).and_raise(::Users::IdentityVerification::Error)
      end
    end

    it 'raises an exception' do
      expect { subject }.to raise_error do |error|
        expect(error.cause).to be_a(::Users::IdentityVerification::Error)
      end
    end
  end

  context 'when the user is authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!)
      end
    end

    it 'does not raise an exception' do
      expect { subject }.not_to raise_error
    end
  end
end
