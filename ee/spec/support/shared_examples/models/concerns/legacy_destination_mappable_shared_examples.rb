# frozen_string_literal: true

RSpec.shared_examples 'includes LegacyDestinationMappable concern' do |factory_name, model_class|
  describe model_class do
    let(:model_factory_name) { factory_name }
    let(:is_instance) { model_class <= AuditEvents::Instance::ExternalStreamingDestination }

    describe 'validations' do
      subject { destination }

      let(:destination) { build(model_factory_name) }

      it { is_expected.to be_a(AuditEvents::LegacyDestinationMappable) }

      context 'when legacy_destination_ref' do
        if model_class <= AuditEvents::Instance::ExternalStreamingDestination
          context 'for instance level destinations' do
            subject { instance_destination }

            let(:instance_destination) { build(model_factory_name, :http) }

            it 'is valid when nil' do
              instance_destination.legacy_destination_ref = nil

              expect(instance_destination).to be_valid
            end

            it 'allows same legacy_destination_ref for different categories' do
              create(model_factory_name, :http, legacy_destination_ref: 1)
              instance_destination.legacy_destination_ref = 1
              instance_destination = build(model_factory_name, :gcp, legacy_destination_ref: 1)

              expect(instance_destination).to be_valid
            end

            it 'enforces uniqueness within same category' do
              create(model_factory_name, :http, legacy_destination_ref: 1)
              instance_destination = build(model_factory_name, :http, legacy_destination_ref: 1)

              expect(instance_destination).not_to be_valid
              expect(instance_destination.errors[:legacy_destination_ref]).to include('has already been taken')
            end
          end
        else
          context 'for group level destinations' do
            subject { group_destination }

            let(:group) { create(:group) }
            let(:other_group) { create(:group) }
            let(:group_destination) { build(model_factory_name, :http, group: group) }

            it 'is valid when nil' do
              group_destination.legacy_destination_ref = nil

              expect(group_destination).to be_valid
            end

            it 'allows same legacy_destination_ref for different categories within same group' do
              create(model_factory_name, :http, legacy_destination_ref: 1, group: group)
              group_destination = build(model_factory_name, :gcp, legacy_destination_ref: 1, group: group)

              expect(group_destination).to be_valid
            end

            it 'enforces uniqueness for same category within same group' do
              create(model_factory_name, :http, legacy_destination_ref: 1, group: group)
              group_destination = build(model_factory_name, :http, legacy_destination_ref: 1, group: group)

              expect(group_destination).not_to be_valid
              expect(group_destination.errors[:legacy_destination_ref]).to include('has already been taken')
            end

            it 'allows same legacy_destination_ref and category in different groups' do
              create(model_factory_name, :http, legacy_destination_ref: 1, group: other_group)
              group_destination = build(model_factory_name, :http, legacy_destination_ref: 1, group: group)

              expect(group_destination).to be_valid
            end
          end
        end
      end
    end

    describe 'group and instance level checks' do
      subject(:destination) { build(model_factory_name) }

      context 'when checking #_level?' do
        it 'correctly identifies instance vs group level destinations' do
          if is_instance
            expect(destination.instance_level?).to be true
            expect(destination.group_level?).to be false
          else
            expect(destination.group_level?).to be true
            expect(destination.instance_level?).to be false
          end
        end
      end
    end

    describe '#legacy_destination' do
      using RSpec::Parameterized::TableSyntax
      let(:instance_destination) { build(model_factory_name, :http) }
      let(:group_destination) { build(model_factory_name, :http, group: create(:group)) }
      let(:destination) { is_instance ? instance_destination : group_destination }

      let(:legacy_http_model) do
        is_instance ? AuditEvents::InstanceExternalAuditEventDestination : AuditEvents::ExternalAuditEventDestination
      end

      let(:legacy_destination_ref) { 1 }
      let(:legacy_models) do
        if is_instance
          {
            http: [AuditEvents::InstanceExternalAuditEventDestination, 'instance_external_audit_event_destination'],
            aws: [AuditEvents::Instance::AmazonS3Configuration, 'instance_amazon_s3_configuration'],
            gcp: [AuditEvents::Instance::GoogleCloudLoggingConfiguration, 'instance_google_cloud_logging_configuration']
          }
        else
          {
            http: [AuditEvents::ExternalAuditEventDestination, 'external_audit_event_destination'],
            aws: [AuditEvents::AmazonS3Configuration, 'amazon_s3_configuration'],
            gcp: [AuditEvents::GoogleCloudLoggingConfiguration, 'google_cloud_logging_configuration']
          }
        end
      end

      where(:trait) do
        [:http, :aws, :gcp]
      end

      with_them do
        it 'looks up correct legacy model' do
          destination = create(model_factory_name, trait, legacy_destination_ref: legacy_destination_ref)
          _, legacy_factory = legacy_models[trait]
          legacy_record = if is_instance
                            create(legacy_factory, id: legacy_destination_ref)
                          else
                            create(legacy_factory, id: legacy_destination_ref,
                              namespace_id: create(:group).id)
                          end

          expect(destination.legacy_destination).to eq(legacy_record)
        end
      end

      it 'returns nil with no legacy_destination_ref' do
        destination = build(model_factory_name, :http)
        destination.legacy_destination_ref = nil

        expect(destination.legacy_destination).to be_nil
      end

      it 'returns nil with no category' do
        destination = build(model_factory_name, :http, legacy_destination_ref: legacy_destination_ref)
        destination.category = nil
        destination.legacy_destination_ref = 1

        expect(destination.legacy_destination).to be_nil
      end

      it 'returns nil when legacy model is not found' do
        destination = build(model_factory_name, :http, legacy_destination_ref: 999)

        expect(destination.legacy_destination).to be_nil
      end

      it 'calls find_by with legacy_destination_ref' do
        legacy_ref = if is_instance
                       create(:instance_external_audit_event_destination).id
                     else
                       group = create(:group)

                       create(
                         :external_audit_event_destination, group: group).id
                     end

        destination.legacy_destination_ref = legacy_ref
        destination.category = 'http'

        expect(legacy_http_model).to receive(:find_by).with(id: legacy_ref)

        destination.legacy_destination
      end

      context 'when instance level' do
        it 'looks up legacy model based on category' do
          if is_instance
            legacy_ref = create(:instance_external_audit_event_destination).id
            destination.legacy_destination_ref = legacy_ref
            destination.category = 'http'

            expect(destination.legacy_destination).to eq(
              AuditEvents::InstanceExternalAuditEventDestination.find(legacy_ref)
            )
            expect(AuditEvents::InstanceExternalAuditEventDestination).to receive(:find_by).with(id: legacy_ref)

            destination.legacy_destination
          end
        end
      end

      context 'when group level' do
        it 'looks up legacy model based on category' do
          unless is_instance
            group = create(:group)
            legacy_ref = create(:external_audit_event_destination, group: group).id

            destination.category = 'http'
            destination.legacy_destination_ref = legacy_ref
            destination.group = group

            expect(destination.legacy_destination).to eq(
              AuditEvents::ExternalAuditEventDestination.find(legacy_ref)
            )
            expect(AuditEvents::ExternalAuditEventDestination).to receive(:find_by).with(id: legacy_ref)

            destination.legacy_destination
          end
        end
      end
    end

    describe '#instance_legacy_models' do
      subject(:destination) { build(model_factory_name) }

      it 'contains expected key/value pairs' do
        expected = {
          http: AuditEvents::InstanceExternalAuditEventDestination,
          aws: AuditEvents::Instance::AmazonS3Configuration,
          gcp: AuditEvents::Instance::GoogleCloudLoggingConfiguration
        }

        expect(destination.send(:instance_legacy_models)).to eq(expected)
      end
    end

    describe '#group_legacy_models' do
      subject(:destination) { build(model_factory_name) }

      it 'contains expected key/value pairs' do
        expected = {
          http: AuditEvents::ExternalAuditEventDestination,
          aws: AuditEvents::AmazonS3Configuration,
          gcp: AuditEvents::GoogleCloudLoggingConfiguration
        }

        expect(destination.send(:group_legacy_models)).to eq(expected)
      end
    end
  end
end
