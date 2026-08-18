# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::CloudflareExposedCredentialChecker, feature_category: :system_access do
  let(:headers) { {} }

  let(:request) do
    instance_double(
      ActionDispatch::Request,
      headers: headers
    )
  end

  subject(:check) { described_class.new(request) }

  context 'when value is 1 (CF docs: Previously leaked username and password detected)' do
    let(:headers) { { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => '1' } }

    it 'has result :exact_username_and_password and all exact methods returns true' do
      expect(check.result).to eq :exact_username_and_password
      expect(check.exact_username_and_password?).to be true
      expect(check.exact_username?).to be true
      expect(check.exact_password?).to be true
      expect(check.similar_username_and_password?).to be false
    end
  end

  context 'when value is 2 (CF docs: Previously leaked username detected)' do
    let(:headers) { { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => '2' } }

    it 'has result :exact_username and only exact_username? returns true' do
      expect(check.result).to eq :exact_username
      expect(check.exact_username_and_password?).to be false
      expect(check.exact_username?).to be true
      expect(check.exact_password?).to be false
      expect(check.similar_username_and_password?).to be false
    end
  end

  context 'when value is 3 (CF docs: Similar combination of previously leaked username and password detected)' do
    let(:headers) { { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => '3' } }

    it 'has result :similar_username_and_password and only similar_username_and_password? returns true' do
      expect(check.result).to eq :similar_username_and_password
      expect(check.exact_username_and_password?).to be false
      expect(check.exact_username?).to be false
      expect(check.exact_password?).to be false
      expect(check.similar_username_and_password?).to be true
    end
  end

  context 'when value is 4 (CF docs: Previously leaked password detected)' do
    let(:headers) { { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => '4' } }

    it 'has result :exact_password and only exact_password? returns true' do
      expect(check.result).to eq :exact_password
      expect(check.exact_username_and_password?).to be false
      expect(check.exact_username?).to be false
      expect(check.exact_password?).to be true
      expect(check.similar_username_and_password?).to be false
    end
  end

  shared_examples 'no result or matches' do
    it 'has a nil result and returns false for all match methods' do
      expect(check.result).to be_nil
      expect(check.exact_username_and_password?).to be false
      expect(check.exact_username?).to be false
      expect(check.exact_password?).to be false
      expect(check.similar_username_and_password?).to be false
    end
  end

  context 'when invalid check value present in request' do
    let(:headers) { { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => '9' } }

    it_behaves_like 'no result or matches'
  end

  context 'when no check value present in request' do
    it_behaves_like 'no result or matches'
  end
end
