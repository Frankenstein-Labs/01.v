# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AwsDestinationValidator, feature_category: :audit_events do
  subject(:validator) { described_class.new }

  let_it_be(:group) { create(:group) }
  let(:secret_token) { 'some_secret_token' }

  describe "#validate" do
    context 'for config' do
      context 'when record is group external destination' do
        let(:destination) { create(:audit_events_group_external_streaming_destination, :aws, group: group) }

        context 'when record is being created' do
          context 'when bucket name is unique' do
            let(:new_destination) do
              AuditEvents::Group::ExternalStreamingDestination.new(
                config: { accessKeyXid: SecureRandom.hex(8),
                          bucketName: SecureRandom.hex(8),
                          awsRegion: "ap-south-2" }, group: group, category: 'aws', secret_token: SecureRandom.hex(8))
            end

            it 'does not raise error' do
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when bucket name already exists' do
            context 'when destination belongs to same group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: group, category: 'aws', secret_token: SecureRandom.hex(8))
              end

              it 'raises error' do
                validator.validate(new_destination)

                expect(new_destination.errors.full_messages)
                  .to include(_('Config bucketName already taken.'))
              end
            end

            context 'when destination belongs to other group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: create(:group), category: 'aws', secret_token: SecureRandom.hex(8)
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
          let(:new_destination) { create(:audit_events_group_external_streaming_destination, :aws, group: group) }

          context 'when bucketName is same as previous value' do
            it 'does not raise error' do
              new_destination.secret_token = SecureRandom.hex(8)
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when bucketName exists for other destination' do
            it 'raises error' do
              new_destination.config = destination.config

              validator.validate(new_destination)

              expect(new_destination.errors.full_messages)
                .to include(_('Config bucketName already taken.'))
            end
          end
        end
      end

      context 'when record is instance external destination' do
        let(:destination) { create(:audit_events_instance_external_streaming_destination, :aws) }

        context 'when config url is unique' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: { accessKeyXid: SecureRandom.hex(8),
                        bucketName: SecureRandom.hex(8),
                        awsRegion: "ap-south-2" }, category: 'aws', secret_token: SecureRandom.hex(8))
          end

          it 'does not raise error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages).to be_empty
          end
        end

        context 'when bucketName already exists' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: destination.config, category: 'aws', secret_token: SecureRandom.hex(8))
          end

          it 'raises error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages)
              .to include(_('Config bucketName already taken.'))
          end
        end
      end
    end

    context 'when category of record is not aws' do
      let(:http_destination) { create(:audit_events_instance_external_streaming_destination) }

      it 'raises error' do
        validator.validate(http_destination)

        expect(http_destination.errors.full_messages)
          .to include(_('AwsDestinationValidator validates only aws external audit event destinations.'))
      end
    end

    context 'when record is not an external destination' do
      let(:user) { create(:user) }

      it 'raises error' do
        validator.validate(user)

        expect(user.errors.full_messages)
          .to include(_('AwsDestinationValidator validates only aws external audit event destinations.'))
      end
    end
  end
end
