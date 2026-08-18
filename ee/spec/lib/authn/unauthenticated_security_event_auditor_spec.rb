# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Authn::UnauthenticatedSecurityEventAuditor, feature_category: :audit_events do
  let(:user_model) { create(:user) }
  let(:user_string) { 'test_login' }

  describe '#initialize' do
    context 'when user_or_login is a User model' do
      subject(:create_auditor) { described_class.new(user_model) }

      it 'sets author and scope as the user model' do
        expect(create_auditor.author).to eq(user_model)
        expect(create_auditor.scope).to eq(user_model)
      end
    end

    context 'when user_or_login is a string' do
      subject(:create_auditor) { described_class.new(user_string) }

      it 'sets author as UnauthenticatedAuthor' do
        expect(create_auditor.author).to be_a(Gitlab::Audit::UnauthenticatedAuthor)
        expect(create_auditor.author.name).to eq(user_string)
      end

      it 'sets scope as InstanceScope' do
        expect(create_auditor.scope).to be_a(Gitlab::Audit::InstanceScope)
      end
    end

    context 'when user_or_login is nil' do
      subject(:create_auditor) { described_class.new(nil) }

      it 'sets author as UnauthenticatedAuthor with empty string name' do
        expect(create_auditor.author).to be_a(Gitlab::Audit::UnauthenticatedAuthor)
        expect(create_auditor.author.name).to eq('An unauthenticated user')
      end

      it 'sets scope as InstanceScope' do
        expect(create_auditor.scope).to be_a(Gitlab::Audit::InstanceScope)
      end
    end

    it 'sets authentication_method' do
      create_auditor = described_class.new(user_string, 'TEST_METHOD')
      expect(create_auditor.authentication_method).to eq('TEST_METHOD')
    end
  end

  describe '#execute' do
    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit).and_return(true)
    end

    context 'when user_or_login is a User model' do
      subject(:create_auditor) { described_class.new(user_model) }

      it 'calls Gitlab::Audit::Auditor.audit with correct parameters' do
        create_auditor.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            name: 'login_failed_with_standard_authentication',
            scope: user_model,
            author: user_model,
            target: user_model,
            message: 'Failed to login with STANDARD authentication',
            additional_details: { failed_login: 'STANDARD' }
          )
        )
      end
    end

    context 'when user_or_login is a string' do
      subject(:create_auditor) { described_class.new(user_string) }

      it 'calls Gitlab::Audit::Auditor.audit with correct parameters' do
        create_auditor.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            name: 'login_failed_with_standard_authentication',
            scope: instance_of(Gitlab::Audit::InstanceScope),
            author: instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            target: instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            message: 'Failed to login with STANDARD authentication',
            additional_details: { failed_login: 'STANDARD' }
          )
        )
      end
    end

    context 'when user_or_login is nil' do
      subject(:create_auditor) { described_class.new(nil) }

      it 'calls Gitlab::Audit::Auditor.audit with correct parameters' do
        create_auditor.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            name: 'login_failed_with_standard_authentication',
            scope: instance_of(Gitlab::Audit::InstanceScope),
            author: instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            target: instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            message: 'Failed to login with STANDARD authentication',
            additional_details: { failed_login: 'STANDARD' }
          )
        )
      end

      it 'uses an empty string for the UnauthenticatedAuthor name' do
        create_auditor.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit) do |args|
          expect(args[:author].name).to eq('An unauthenticated user')
          expect(args[:target].name).to eq('An unauthenticated user')
        end
      end
    end
  end
end
