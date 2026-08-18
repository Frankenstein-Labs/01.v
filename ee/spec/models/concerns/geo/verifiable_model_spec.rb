# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerifiableModel, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  context 'when separate table is used for verification state' do
    before_all do
      create_dummy_model_with_separate_state_table
    end

    after(:all) do
      drop_dummy_model_with_separate_state_table
    end

    before do
      stub_dummy_replicator_class(model_class: 'TestDummyModelWithSeparateState')
      stub_dummy_model_with_separate_state_class
    end

    subject { TestDummyModelWithSeparateState.new }

    describe '.verification_state_model_key' do
      it 'returns the primary key of the state model' do
        expect(subject.class.verification_state_model_key).to eq(TestDummyModelState.primary_key)
      end
    end

    describe '.active_record_state_association' do
      it 'returns the association for the state table' do
        expect(subject.class.active_record_state_association.name).to eq(:_test_dummy_model_state)
      end
    end

    describe '#in_verifiables?' do
      it 'returns true when the verifiables scope includes the instance' do
        subject.save!

        expect(subject.in_verifiables?).to be(true)
      end

      it 'returns false when the verifiables scope does not include the instance' do
        expect(subject.in_verifiables?).to be(false)
      end
    end

    describe '.available_verifiables' do
      before do
        stub_primary_site
        allow(Gitlab::Geo::Replicator).to receive_messages(verification_enabled?: true, replication_enabled?: true)

        subject.save!
      end

      it 'returns records that have verification state records' do
        expect(subject.class.available_verifiables).to include(subject)
      end

      it 'joins the state table' do
        expect(subject.class.available_verifiables.to_sql)
          .to include('JOIN "_test_dummy_model_states"')
      end

      it 'is chainable with other scopes' do
        expect { subject.class.available_verifiables.where(id: 1) }
          .not_to raise_error
      end

      context 'when no state records exist' do
        before do
          subject.class.delete_all
        end

        it 'returns empty relation' do
          expect(subject.class.available_verifiables).to be_empty
        end
      end
    end
  end

  context 'when separate table is not used for verification state' do
    before_all do
      create_dummy_model_table
    end

    after(:all) do
      drop_dummy_model_table
    end

    before do
      stub_dummy_replicator_class
      stub_dummy_model_class
    end

    subject { DummyModel.new }

    describe '.verification_state_object' do
      it 'returns self' do
        expect(subject.verification_state_object.id).to eq(subject.id)
      end
    end

    describe '.verification_state_model_key' do
      it 'returns the primary key of the model' do
        expect(subject.class.verification_state_model_key).to eq(DummyModel.primary_key)
      end
    end

    describe '#in_verifiables?' do
      it 'returns true when the verifiables scope includes the instance' do
        subject.save!

        expect(subject.in_verifiables?).to be(true)
      end

      it 'returns false when the verifiables scope does not include the instance' do
        expect(subject.in_verifiables?).to be(false)
      end
    end

    describe '.active_record_state_association' do
      it 'returns nil' do
        expect(subject.class.active_record_state_association).to be_nil
      end
    end

    describe '.available_verifiables' do
      before do
        stub_primary_site
        allow(Gitlab::Geo::Replicator).to receive_messages(verification_enabled?: true, replication_enabled?: true)

        subject.save!
      end

      it 'returns verifiable records' do
        expect(subject.class).to receive(:verifiables).and_call_original
        expect(subject.class.available_verifiables).to include(subject)
      end

      it 'does not join the state table' do
        expect(subject.class.available_verifiables.to_sql)
          .not_to include('JOIN')
      end

      it 'is chainable with other scopes' do
        expect { subject.class.available_verifiables.where(id: 1) }
          .not_to raise_error
      end

      context 'when no state records exist' do
        before do
          subject.class.delete_all
        end

        it 'returns empty relation' do
          expect(subject.class.available_verifiables).to be_empty
        end
      end
    end
  end

  context 'when using the with_state_details scope' do
    where(model_classes: Gitlab::Geo::ModelMapper.available_models)
    with_them do
      let(:factory) { factory_name(model_classes) }

      it 'prevents n+1 queries' do
        create_list(factory, 4)

        expect { model_classes.with_state_details.all.map(&:verification_state) }
          .not_to exceed_query_limit(2)
      end
    end
  end
end
