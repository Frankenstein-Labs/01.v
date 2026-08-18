# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Replicator, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node) }

  before_all do
    create_dummy_model_table
  end

  after(:all) do
    drop_dummy_model_table
  end

  before do
    stub_dummy_replicator_class
    stub_dummy_replication_feature_flag
    stub_current_geo_node(secondary_node)
  end

  context 'event DSL' do
    subject { Geo::DummyReplicator }

    describe '.supported_events' do
      it 'expects :test event to be supported' do
        expect(subject.supported_events).to match_array([:test, :another_test])
      end
    end

    describe '.event_supported?' do
      it 'expects a supported event to return true' do
        expect(subject.event_supported?(:test)).to be_truthy
      end

      it 'expect an unsupported event to return false' do
        expect(subject.event_supported?(:something_else)).to be_falsey
      end
    end
  end

  describe '#publish' do
    subject { Geo::DummyReplicator.new }

    context 'when publishing a supported events with required params' do
      it 'creates event with associated event log record' do
        stub_current_geo_node(primary_node)

        expect { subject.publish(:test, other: true) }.to change { ::Geo::EventLog.count }.from(0).to(1)

        expect(::Geo::EventLog.last.event).to be_a(::Geo::Event)
      end
    end

    context 'when publishing unsupported event' do
      it 'raises an argument error' do
        expect { subject.publish(:unsupported) }.to raise_error(ArgumentError)
      end
    end

    context 'when replicator should not publish events' do
      before do
        allow(subject).to receive(:should_publish_replication_event?).and_return(false)
      end

      it 'returns nil' do
        expect(subject.publish(:test)).to be_nil
      end
    end
  end

  describe '#consume' do
    subject { Geo::DummyReplicator.new }

    it 'accepts valid attributes' do
      expect { subject.consume(:test, user: 'something', other: 'something else') }.not_to raise_error
    end

    it 'calls corresponding method with specified named attributes' do
      expect(subject).to receive(:consume_event_test).with(user: 'something', other: 'something else')

      subject.consume(:test, user: 'something', other: 'something else')
    end
  end

  describe '#create_event_with' do
    let(:replicator) { Geo::DummyReplicator.new }
    let(:params) { { replicable_name: 'dummy', event_name: :created, payload: { id: 1 } } }

    subject { replicator.send(:create_event_with, **params) }

    before do
      stub_current_geo_node(primary_node)
    end

    context 'when on primary with secondary nodes' do
      before do
        allow(Gitlab::Geo).to receive(:secondary_nodes).and_return([secondary_node])
      end

      context 'when event creation succeeds' do
        it 'creates a Geo::Event with provided parameters' do
          # Use a double to test that the first created event is used for the EventLog creation
          double = instance_double(Geo::Event)
          # Stub that the event was persisted
          allow(double).to receive(:persisted?).and_return(true)

          expect(Geo::Event).to receive(:create!).with(**params).and_return(double)
          expect(Geo::EventLog).to receive(:create!).with(geo_event: double)

          subject
        end

        it 'returns an event' do
          expect(subject).to be_a(Geo::Event)
        end

        it 'creates one geo event' do
          expect { subject }.to change { ::Geo::Event.count }.from(0).to(1)
        end

        it 'creates one geo event log' do
          expect { subject }.to change { ::Geo::EventLog.count }.from(0).to(1)
        end
      end

      context 'when event creation fails with ActiveRecord::RecordInvalid' do
        let(:error) { ActiveRecord::RecordInvalid.new }

        before do
          allow(Geo::Event).to receive(:create!).and_raise(error)
        end

        it 'logs the error with correct parameters' do
          expect(replicator).to receive(:log_error).with("::Geo::Event could not be created", error, params)

          subject
        end

        it 'does not raise the error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when event creation fails with NoMethodError' do
        let(:error) { NoMethodError.new }

        before do
          allow(Geo::Event).to receive(:create!).and_raise(error)
        end

        it 'handles NoMethodError and logs it' do
          expect(replicator).to receive(:log_error).with("::Geo::Event could not be created", error, params)

          subject
        end

        it 'does not raise the error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when event creation fails with unexpected error' do
        let(:error) { StandardError.new }

        before do
          allow(Geo::Event).to receive(:create!).and_raise(error)
        end

        it 'does raise the error' do
          expect { subject }.to raise_error(error)
        end
      end

      context 'when Geo::EventLog creation fails inside transaction' do
        before do
          allow(Geo::EventLog).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)
        end

        it 'does not create a Geo::Event' do
          expect { subject }.not_to change { ::Geo::Event.count }
        end
      end

      context 'when transaction is rolled back' do
        before do
          allow(Geo::EventLog).to receive(:create!).and_raise(ActiveRecord::Rollback.new)
        end

        it 'does not create a Geo::Event' do
          expect { subject }.not_to change { ::Geo::Event.count }
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end

      context 'when event is nil' do
        it 'returns nil' do
          allow(Geo::Event).to receive(:create!).with(**params).and_return(nil)

          expect(subject).to be_nil
        end
      end
    end

    context 'when not on primary site' do
      before do
        allow(Gitlab::Geo).to receive(:primary?).and_return(false)
      end

      it 'returns nil without creating events' do
        expect(Geo::Event).not_to receive(:create!)
        expect(Geo::EventLog).not_to receive(:create!)
        expect(subject).to be_nil
      end
    end

    context 'when no secondary nodes exist' do
      before do
        allow(Gitlab::Geo).to receive(:secondary_nodes).and_return([])
      end

      it 'returns nil without creating events' do
        expect(Geo::Event).not_to receive(:create!)
        expect(Geo::EventLog).not_to receive(:create!)
        expect(subject).to be_nil
      end
    end
  end

  describe '.for_class_name' do
    context 'when given a Geo RegistryFinder' do
      it 'returns the corresponding Replicator class' do
        expect(described_class.for_class_name('Geo::DummyRegistryFinder')).to eq(Geo::DummyReplicator)
      end
    end

    context 'when given a Geo RegistriesResolver"' do
      it 'returns the corresponding Replicator class' do
        expect(described_class.for_class_name('Geo::DummyRegistriesResolver')).to eq(Geo::DummyReplicator)
      end
    end
  end

  describe '.for_replicable_name' do
    context 'given a valid replicable_name' do
      it 'returns the corresponding Replicator class' do
        replicator_class = described_class.for_replicable_name('dummy')

        expect(replicator_class).to eq(Geo::DummyReplicator)
      end
    end

    context 'given an invalid replicable_name' do
      it 'raises and logs NotImplementedError' do
        expect(Gitlab::Geo::Logger).to receive(:error)

        expect do
          described_class.for_replicable_name('invalid')
        end.to raise_error(NotImplementedError)
      end
    end

    context 'given nil' do
      it 'raises NotImplementedError' do
        expect do
          described_class.for_replicable_name('invalid')
        end.to raise_error(NotImplementedError)
      end
    end
  end

  describe '.model_name' do
    where(:replicators) { described_class.subclasses }
    with_them do
      let(:name) { Gitlab::Geo::ModelMapper.convert_to_name(replicators.model) }

      it 'returns the corresponding model name' do
        expect(replicators.model_name).to eq(name)
      end
    end
  end

  describe '.model_name_plural' do
    where(:replicators) { described_class.subclasses }
    with_them do
      let(:name) { replicators.model_name }

      it 'returns the corresponding model name pluralized' do
        expect(replicators.model_name_plural).to eq(name.pluralize)
      end
    end
  end

  describe '.for_replicable_params' do
    it 'returns the corresponding Replicator instance' do
      replicator = described_class.for_replicable_params(replicable_name: 'dummy', replicable_id: 123456)

      expect(replicator).to be_a(Geo::DummyReplicator)
      expect(replicator.model_record_id).to eq(123456)
    end
  end

  describe '.replicable_params' do
    it 'returns a Hash of data needed to reinstantiate the Replicator' do
      replicator = Geo::DummyReplicator.new(model_record_id: 123456)

      expect(replicator.replicable_params).to eq(replicable_name: 'dummy', replicable_id: 123456)
    end
  end

  describe '.graphql_registry_id_type' do
    before do
      stub_const('Geo::DummyRegistry', Class.new)

      allow(Geo::DummyReplicator).to receive(:registry_class).and_return(Geo::DummyRegistry)
    end

    it 'returns the GobalID GraphQL Type matching this replicator' do
      expect(Geo::DummyReplicator.graphql_registry_id_type.inspect).to eq("GeoDummyRegistryID")
    end
  end

  describe '.bulk_create_delete_events_async' do
    it 'raises NotImplementedError by default' do
      expect { described_class.bulk_create_delete_events_async([]) }.to raise_error(NotImplementedError)
    end
  end

  describe '.bulk_create_events' do
    let(:event) do
      {
        replicable_name: 'upload',
        event_name: 'created',
        payload: {
          data: "some payload"
        },
        created_at: Time.current
      }
    end

    let(:events) { [event] }

    it 'creates events' do
      expect { described_class.bulk_create_events(events) }.to change { ::Geo::EventLog.count }.from(0).to(1)

      expect(::Geo::EventLog.last.event).to be_present
    end
  end

  describe '.status_expiration' do
    context 'when sync_timeout is defined' do
      let(:test_replicator_class) do
        Class.new(described_class) do
          def self.sync_timeout
            4.hours
          end

          def self.replicable_name
            'test_replicable'
          end

          def self.model
            Upload
          end
        end
      end

      it 'returns the sync_timeout value as an integer' do
        expect(test_replicator_class.status_expiration).to eq(4.hours.to_i)
      end

      it 'returns an integer even if sync_timeout returns ActiveSupport::Duration' do
        expect(test_replicator_class.status_expiration).to be_a(Integer)
      end

      it 'validates that sync_timeout is positive' do
        test_class = Class.new(described_class) do
          def self.sync_timeout
            -1
          end

          def self.replicable_name
            'test_negative'
          end

          def self.model
            Upload
          end
        end

        allow(Gitlab::AppLogger).to receive(:warn)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(Gitlab::AppLogger).to receive(:warn)
        expect(test_class.status_expiration).to eq(8.hours.to_i)
      end
    end

    context 'when sync_timeout is not defined' do
      let(:test_replicator_class) do
        Class.new(described_class) do
          def self.replicable_name
            'test_replicable_without_timeout'
          end

          def self.model
            Upload
          end
        end
      end

      it 'returns default 8 hours' do
        allow(Gitlab::AppLogger).to receive(:warn)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(test_replicator_class.status_expiration).to eq(8.hours.to_i)
      end

      it 'logs a warning message' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(Gitlab::AppLogger).to receive(:warn).with(/does not define sync_timeout/)
        test_replicator_class.status_expiration
      end

      it 'tracks exception in Sentry' do
        allow(Gitlab::AppLogger).to receive(:warn)
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
        test_replicator_class.status_expiration
      end

      it 'returns an integer' do
        allow(Gitlab::AppLogger).to receive(:warn)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(test_replicator_class.status_expiration).to be_a(Integer)
      end
    end

    context 'with real replicator classes' do
      it 'returns 8 hours for upload replicator' do
        expect(Geo::UploadReplicator.status_expiration).to eq(8.hours.to_i)
      end

      it 'returns 8 hours for package file replicator' do
        expect(Geo::PackageFileReplicator.status_expiration).to eq(8.hours.to_i)
      end

      it 'returns 8 hours for container repository replicator' do
        expect(Geo::ContainerRepositoryReplicator.status_expiration).to eq(8.hours.to_i)
      end
    end

    context 'when called multiple times' do
      it 'returns consistent values' do
        first_call = Geo::UploadReplicator.status_expiration
        second_call = Geo::UploadReplicator.status_expiration

        expect(first_call).to eq(second_call)
      end
    end
  end

  describe '.oldest_unsynced' do
    before do
      stub_const('Geo::DummyRegistry', Class.new)
      allow(Geo::DummyReplicator).to receive(:registry_class).and_return(Geo::DummyRegistry)
    end

    it 'returns oldest_unsynced_time when it has a value' do
      time = Time.current
      allow(Geo::DummyRegistry).to receive(:oldest_unsynced_time).and_return(time)

      expect(Geo::DummyReplicator.oldest_unsynced).to eq(time)
    end

    it 'returns -1 when oldest_unsynced_time is nil' do
      allow(Geo::DummyRegistry).to receive(:oldest_unsynced_time).and_return(nil)

      expect(Geo::DummyReplicator.oldest_unsynced).to eq(-1)
    end
  end

  describe '#initialize' do
    subject(:replicator) { Geo::DummyReplicator.new(**args) }

    let(:model_record) { double('DummyModel instance', id: 1234) }

    context 'given model_record' do
      let(:args) { { model_record: model_record } }

      it 'sets model_record' do
        expect(replicator.model_record).to eq(model_record)
      end

      it 'sets model_record_id' do
        expect(replicator.model_record_id).to eq(1234)
      end
    end

    context 'given model_record_id' do
      let(:args) { { model_record_id: 1234 } }

      before do
        model = double('DummyModel')
        # These two stubs are needed because `#model_record` instantiates the
        # defined `.model` class.
        allow(Geo::DummyReplicator).to receive(:model).and_return(model)
        allow(model).to receive(:find).with(1234).and_return(model_record)
      end

      it 'sets model_record' do
        expect(replicator.model_record).to eq(model_record)
      end

      it 'sets model_record_id' do
        expect(replicator.model_record_id).to eq(1234)
      end
    end
  end

  describe '#in_replicables_for_current_secondary?' do
    let(:model_record) { double('DummyModel instance', id: 1234, in_replicables_for_current_secondary?: true) }
    let(:replicator) { Geo::DummyReplicator.new(model_record: model_record) }

    it { is_expected.to delegate_method(:in_replicables_for_current_secondary?).to(:model_record) }

    it 'delegates to model_record' do
      expect(replicator.in_replicables_for_current_secondary?).to be(true)
    end
  end

  describe '#fail_record_not_found!' do
    let(:model_record) { double('DummyModel instance', id: 1234) }
    let(:replicator) { Geo::DummyReplicator.new(model_record: model_record) }
    let(:dummy_model_class) { double('DummyModel class') }
    let(:registry) { double('registry', persisted?: true) }

    before do
      allow(Geo::DummyReplicator).to receive(:model).and_return(dummy_model_class)
      allow(replicator).to receive(:registry).and_return(registry)
      allow(registry).to receive(:failed!)
    end

    it 'marks the registry as failed' do
      replicator.fail_record_not_found!

      expected_message = 'The source record was not found. ' \
        'It was likely removed from the primary site before this sync could complete.'
      expect(registry).to have_received(:failed!).with(message: expected_message)
    end

    it 'logs with the replicable details' do
      expect(replicator).to receive(:log_info).with(
        "Couldn't find #{dummy_model_class} with 'id'=1234",
        replicable_name: replicator.replicable_name, model_record_id: 1234
      )

      replicator.fail_record_not_found!
    end

    context 'when the registry is not persisted' do
      let(:registry) { double('registry', persisted?: false) }

      it 'does not call failed!' do
        replicator.fail_record_not_found!

        expect(registry).not_to have_received(:failed!)
      end
    end
  end

  describe '#resource_exists?' do
    it 'raises error when not implemented' do
      expect { subject.resource_exists? }.to raise_error NotImplementedError
    end
  end
end
