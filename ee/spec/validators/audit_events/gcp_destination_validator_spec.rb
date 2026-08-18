# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::GcpDestinationValidator, feature_category: :audit_events do
  subject(:validator) { described_class.new }

  let_it_be(:group) { create(:group) }

  describe "#validate" do
    context 'for config' do
      context 'when record is group external destination' do
        let!(:destination) { create(:audit_events_group_external_streaming_destination, :gcp, group: group) }

        context 'when record is being created' do
          context 'when config is unique' do
            let(:new_destination) do
              AuditEvents::Group::ExternalStreamingDestination.new(
                config: { googleProjectIdName: 'project-id-2',
                          clientEmail: FFaker::Internet.safe_email,
                          logIdName: SecureRandom.hex(4) },
                group: group, category: 'gcp', secret_token: SecureRandom.hex(8)
              )
            end

            it 'does not raise error' do
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when config already exists' do
            context 'when destination belongs to same group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: group, category: 'gcp', secret_token: SecureRandom.hex(8))
              end

              it 'raises error' do
                validator.validate(new_destination)

                expect(new_destination.errors.full_messages)
                  .to include(_('Config logIdName, googleProjectIdName already taken.'))
              end
            end

            context 'when destination belongs to other group' do
              let(:new_destination) do
                AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config, group: create(:group), category: 'gcp', secret_token: SecureRandom.hex(8)
                )
              end

              it 'does not raise error' do
                validator.validate(new_destination)

                expect(new_destination.errors.full_messages).to be_empty
              end
            end
          end

          context 'when config partially exists' do
            context 'when googleProjectIdName is same but logIdName is different' do
              it 'does not raise error' do
                new_destination = AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config,
                  group: create(:group),
                  category: 'gcp',
                  secret_token: SecureRandom.hex(8)
                )

                new_destination.config["logIdName"] = SecureRandom.hex(4)

                validator.validate(new_destination)

                expect(new_destination.errors.full_messages).to be_empty
              end
            end

            context 'when googleProjectIdName is different but logIdName is same' do
              it 'does not raise error' do
                new_destination = AuditEvents::Group::ExternalStreamingDestination.new(
                  config: destination.config,
                  group: create(:group),
                  category: 'gcp',
                  secret_token: SecureRandom.hex(8)
                )

                new_destination.config["googleProjectIdName"] = SecureRandom.hex(4)

                validator.validate(new_destination)

                expect(new_destination.errors.full_messages).to be_empty
              end
            end
          end
        end

        context 'when record is being updated' do
          let(:new_destination) { create(:audit_events_group_external_streaming_destination, :gcp, group: group) }

          context 'when logIdName is same as previous value' do
            it 'does not raise error' do
              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when config exists for other destination' do
            it 'raises error' do
              new_destination.config = destination.config

              validator.validate(new_destination)

              expect(new_destination.errors.full_messages)
                .to include(_('Config logIdName, googleProjectIdName already taken.'))
            end
          end
        end
      end

      context 'when record is instance external destination' do
        let(:destination) { create(:audit_events_instance_external_streaming_destination, :gcp) }

        context 'when config is unique' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: { googleProjectIdName: 'project-id-2',
                        clientEmail: FFaker::Internet.safe_email,
                        logIdName: SecureRandom.hex(4) },
              category: 'gcp', secret_token: SecureRandom.hex(8))
          end

          it 'does not raise error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages).to be_empty
          end
        end

        context 'when config already exists' do
          let(:new_destination) do
            AuditEvents::Instance::ExternalStreamingDestination.new(
              config: destination.config, category: 'gcp', secret_token: SecureRandom.hex(8))
          end

          it 'raises error' do
            validator.validate(new_destination)

            expect(new_destination.errors.full_messages)
              .to include(_('Config logIdName, googleProjectIdName already taken.'))
          end
        end

        context 'when config partially exists' do
          context 'when googleProjectIdName is same but logIdName is different' do
            it 'does not raise error' do
              new_destination = AuditEvents::Instance::ExternalStreamingDestination.new(
                config: destination.config,
                category: 'gcp',
                secret_token: SecureRandom.hex(8)
              )

              new_destination.config["logIdName"] = SecureRandom.hex(4)

              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end

          context 'when googleProjectIdName is different but logIdName is same' do
            it 'does not raise error' do
              new_destination = AuditEvents::Instance::ExternalStreamingDestination.new(
                config: destination.config,
                category: 'gcp',
                secret_token: SecureRandom.hex(8)
              )

              new_destination.config["googleProjectIdName"] = SecureRandom.hex(4)

              validator.validate(new_destination)

              expect(new_destination.errors.full_messages).to be_empty
            end
          end
        end
      end
    end

    context 'when category of record is not gcp' do
      let(:http_destination) { create(:audit_events_instance_external_streaming_destination) }

      it 'raises error' do
        validator.validate(http_destination)

        expect(http_destination.errors.full_messages)
          .to include(_('GcpDestinationValidator validates only gcp external audit event destinations.'))
      end
    end

    context 'when record is not an external destination' do
      let(:user) { create(:user) }

      it 'raises error' do
        validator.validate(user)

        expect(user.errors.full_messages)
          .to include(_('GcpDestinationValidator validates only gcp external audit event destinations.'))
      end
    end
  end
end
