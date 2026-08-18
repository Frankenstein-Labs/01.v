# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::HttpDestinationValidator, feature_category: :audit_events do
  subject(:validator) { described_class.new }

  let_it_be(:group) { create(:group) }
  let(:secret_token) { 'some_secret_token' }

  describe "#validate" do
    context 'for config' do
      context 'when record is group external destination' do
        let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

        context 'when record is being created' do
          context 'when config url is unique' do
            let(:new_destination) do
              AuditEvents::Group::ExternalStreamingDestination.new(
                config: { url: FFaker::Internet.http_url }, group: group, category: 'http', secret_token: secret_token)
            end

            it 'does not raise error' do
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when config url already exists' do
            context 'when destination belongs to same group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: group, category: 'http', secret_token: secret_token)
              end

              it 'raises error' do
                validator.validate(new_destination)

                expect(new_destination.errors.full_messages)
                  .to include(_('Config url already taken.'))
              end
            end

            context 'when destination belongs to other group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: create(:group), category: 'http', secret_token: secret_token
                )
              end

              it 'does not raise error' do
                validator.validate(new_destination)

                expect(new_destination.errors.full_messages).to be_empty
              end
            end
          end
        end

        context 'when record is being updated' do
          let(:new_destination) { create(:audit_events_group_external_streaming_destination, group: group) }

          context 'when config url is same as previous value' do
            it 'does not raise error' do
              new_destination.secret_token = 'some_secret_token'
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when config url exists for other destination' do
            it 'raises error' do
              new_destination.config = destination.config

              validator.validate(new_destination)

              expect(new_destination.errors.full_messages)
                .to include(_('Config url already taken.'))
            end
          end
        end
      end

      context 'when record is instance external destination' do
        let(:destination) { create(:audit_events_instance_external_streaming_destination) }

        context 'when config url is unique' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: { url: FFaker::Internet.http_url }, category: 'http', secret_token: secret_token)
          end

          it 'does not raise error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages).to be_empty
          end
        end

        context 'when config url already exists' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: destination.config, category: 'http', secret_token: secret_token)
          end

          it 'raises error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages)
              .to include(_('Config url already taken.'))
          end
        end
      end
    end

    context 'for secret_token' do
      context 'when length is valid' do
        it 'does not raise error' do
          destination = AuditEvents::Group::ExternalStreamingDestination.new(
            config: { url: FFaker::Internet.http_url }, group: group, category: 'http', secret_token: secret_token)

          validator.validate(destination)

          expect(destination.errors.full_messages).to be_empty
        end
      end

      context 'when length is invalid' do
        shared_examples 'raises secret token length error' do
          it do
            validator.validate(destination)

            expect(destination.errors.full_messages)
              .to include('Secret token should have length between 16 to 24 characters.')
          end
        end

        context 'when token is smaller than allowed value' do
          let(:destination) do
            AuditEvents::Group::ExternalStreamingDestination.new(
              config: { url: FFaker::Internet.http_url }, group: group, category: 'http', secret_token: 'abcd')
          end

          it_behaves_like 'raises secret token length error'
        end

        context 'when token is larger than allowed value' do
          let(:destination) do
            AuditEvents::Group::ExternalStreamingDestination.new(
              config: { url: FFaker::Internet.http_url }, group: group, category: 'http',
              secret_token: "larger_than_expected_token_string")
          end

          it_behaves_like 'raises secret token length error'
        end
      end
    end

    context 'when category of record is not http' do
      let(:aws_destination) { create(:audit_events_instance_external_streaming_destination, :aws) }

      it 'raises error' do
        validator.validate(aws_destination)

        expect(aws_destination.errors.full_messages)
          .to include(_('HttpDestinationValidator validates only http external audit event destinations.'))
      end
    end

    context 'when record is not an external destination' do
      let(:user) { create(:user) }

      it 'raises error' do
        validator.validate(user)

        expect(user.errors.full_messages)
          .to include(_('HttpDestinationValidator validates only http external audit event destinations.'))
      end
    end
  end
end
