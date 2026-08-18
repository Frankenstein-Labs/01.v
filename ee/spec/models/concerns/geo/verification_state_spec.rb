# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerificationState, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node, :secondary) }

  context 'for model classes' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'when verification state is stored in the model table' do
      before_all do
        create_dummy_model_table
      end

      after(:all) do
        drop_dummy_model_table
      end

      before do
        stub_dummy_replicator_class
        stub_dummy_model_class
        stub_dummy_replication_feature_flag
      end

      subject(:model_record) { DummyModel.new }

      context 'state machine' do
        context 'when failed' do
          before do
            subject.verification_started
            subject.verification_failed_with_message!('foo')
          end

          context 'and transitioning to pending' do
            it 'marks verification as pending' do
              subject.verification_pending!

              expect(subject.reload.verification_pending?).to be_truthy
            end

            it 'does not clear retry attributes' do
              subject.verification_pending!

              expect(subject.reload).to have_attributes(
                verification_state: DummyModel.verification_state_value(:verification_pending),
                verification_retry_count: 1,
                verification_retry_at: be_present
              )
            end

            it 'logs the verification state transition' do
              expect(Gitlab::Geo::Logger).to receive(:debug).with(
                hash_including(
                  message: 'Verification state transition',
                  class: model_record.class.name,
                  id: model_record.id,
                  model_record_id: model_record.id,
                  from: 'verification_failed',
                  to: 'verification_pending',
                  result: true
                )
              )

              model_record.verification_pending!
            end
          end
        end

        it 'logs verification state transitions' do
          model_record.save!

          expect(Gitlab::Geo::Logger).to receive(:debug).with(
            hash_including(
              message: 'Verification state transition',
              class: model_record.class.name,
              id: model_record.id,
              model_record_id: model_record.id,
              from: 'verification_pending',
              to: 'verification_started',
              result: true
            )
          )

          model_record.verification_started

          expect(Gitlab::Geo::Logger).to receive(:debug).with(
            hash_including(
              message: 'Verification state transition',
              class: model_record.class.name,
              id: model_record.id,
              model_record_id: model_record.id,
              from: 'verification_started',
              to: 'verification_succeeded',
              result: true
            )
          )

          model_record.verification_succeeded_with_checksum!('123', Time.current)

          expect(Gitlab::Geo::Logger).to receive(:debug).with(
            hash_including(
              message: 'Verification state transition',
              class: model_record.class.name,
              id: model_record.id,
              model_record_id: model_record.id,
              from: 'verification_succeeded',
              to: 'verification_started',
              result: true
            )
          )

          model_record.verification_started

          expect(Gitlab::Geo::Logger).to receive(:warn).with(
            hash_including(
              message: 'Verification state transition',
              class: model_record.class.name,
              id: model_record.id,
              model_record_id: model_record.id,
              from: 'verification_started',
              to: 'verification_failed',
              result: true
            )
          )

          model_record.verification_failed_with_message!('foo')

          expect(Gitlab::Geo::Logger).to receive(:info).with(
            hash_including(
              message: 'Verification state transition',
              class: model_record.class.name,
              id: model_record.id,
              model_record_id: model_record.id,
              from: 'verification_failed',
              to: 'verification_disabled',
              result: true
            )
          )

          model_record.verification_disabled
        end
      end

      describe '.verification_pending_batch' do
        # Insert 2 records for a total of 3 with subject
        let!(:other_pending_records) do
          DummyModel.insert_all(
            [
              { verification_state: pending_value, verified_at: 7.days.ago },
              { verification_state: pending_value, verified_at: 6.days.ago }
            ], returning: [:id])
        end

        let(:pending_value) { DummyModel.verification_state_value(:verification_pending) }
        let(:other_pending_ids) { other_pending_records.map { |result| result['id'] } }

        before do
          subject.save!
        end

        it 'returns IDs of rows pending verification' do
          expect(subject.class.verification_pending_batch(batch_size: 3)).to include(subject.id)
        end

        it 'marks verification as started' do
          subject.class.verification_pending_batch(batch_size: 3)

          expect(subject.reload.verification_started?).to be_truthy
          expect(subject.verification_started_at).to be_present
        end

        it 'limits with batch_size and orders records by verified_at with NULLs first' do
          expected = [subject.id, other_pending_ids.first]

          # `match_array` instead of `eq` because the UPDATE query does not
          # guarantee that results are returned in the same order as the subquery
          # used to SELECT the correct batch.
          expect(subject.class.verification_pending_batch(batch_size: 2)).to match_array(expected)
        end

        context 'other verification states' do
          it 'does not include them' do
            subject.verification_started!

            expect(subject.class.verification_pending_batch(batch_size: 3)).not_to include(subject.id)

            subject.verification_succeeded_with_checksum!('foo', Time.current)

            expect(subject.class.verification_pending_batch(batch_size: 3)).not_to include(subject.id)

            subject.verification_started
            subject.verification_failed_with_message!('foo')

            expect(subject.class.verification_pending_batch(batch_size: 3)).not_to include(subject.id)
          end
        end

        it 'logs the verification state transition' do
          expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
            message: 'Batch verification state transition',
            table: model_record.class.verification_state_table_name,
            "#{model_record.class.verification_state_model_key}": match(/\d+,\d+,\d+/),
            count: 3,
            from: 'verification_pending',
            to: 'verification_started',
            method: 'verification_pending_batch'
          ))

          model_record.class.verification_pending_batch(batch_size: 4)
        end
      end

      describe '.verification_failed_batch' do
        # Insert 2 records for a total of 3 with subject
        let!(:other_failed_records) do
          DummyModel.insert_all(
            [
              { verification_state: failed_value, verification_retry_at: 7.days.ago },
              { verification_state: failed_value, verification_retry_at: 6.days.ago }
            ], returning: [:id])
        end

        let(:failed_value) { DummyModel.verification_state_value(:verification_failed) }
        let(:other_failed_ids) { other_failed_records.map { |result| result['id'] } }

        before do
          subject.verification_started
          subject.verification_failed_with_message!('foo')
        end

        context 'with a failed record with retry due' do
          before do
            subject.update!(verification_retry_at: 1.minute.ago)
          end

          it 'returns IDs of rows pending verification' do
            expect(subject.class.verification_failed_batch(batch_size: 3)).to include(subject.id)
          end

          it 'marks verification as started' do
            subject.class.verification_failed_batch(batch_size: 3)

            expect(subject.reload.verification_started?).to be_truthy
            expect(subject.verification_started_at).to be_present
          end

          it 'limits with batch_size and orders records by verification_retry_at with NULLs first' do
            expected = other_failed_ids

            # `match_array` instead of `eq` because the UPDATE query does not
            # guarantee that results are returned in the same order as the subquery
            # used to SELECT the correct batch.
            expect(subject.class.verification_failed_batch(batch_size: 2)).to match_array(expected)
          end

          context 'other verification states' do
            it 'does not include them' do
              subject.verification_started!

              expect(subject.class.verification_failed_batch(batch_size: 5)).not_to include(subject.id)

              subject.verification_succeeded_with_checksum!('foo', Time.current)

              expect(subject.class.verification_failed_batch(batch_size: 5)).not_to include(subject.id)

              subject.verification_pending!

              expect(subject.class.verification_failed_batch(batch_size: 5)).not_to include(subject.id)
            end
          end

          it 'logs the verification state transition' do
            expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
              message: 'Batch verification state transition',
              table: model_record.class.verification_state_table_name,
              "#{model_record.class.verification_state_model_key}": match(/\d+,\d+,\d+/),
              count: 3,
              from: 'verification_failed',
              to: 'verification_started',
              method: 'verification_failed_batch'
            ))

            model_record.class.verification_failed_batch(batch_size: 4)
          end
        end

        context 'when verification_retry_at is in the future' do
          it 'does not return the row' do
            subject.update!(verification_retry_at: 1.minute.from_now)

            expect(subject.class.verification_failed_batch(batch_size: 3)).not_to include(subject.id)
          end
        end
      end

      describe '.needs_verification' do
        it 'includes verification_pending' do
          subject.save!

          expect(subject.class.needs_verification).to include(subject)
        end

        it 'includes verification_failed and verification_retry_due' do
          subject.verification_started
          subject.verification_failed_with_message!('foo')
          subject.update!(verification_retry_at: 1.minute.ago)

          expect(subject.class.needs_verification).to include(subject)
        end

        it 'excludes verification_failed with future verification_retry_at' do
          subject.verification_started
          subject.verification_failed_with_message!('foo')
          subject.update!(verification_retry_at: 1.minute.from_now)

          expect(subject.class.needs_verification).not_to include(subject)
        end
      end

      describe '.needs_reverification' do
        let(:pending_value) { DummyModel.verification_state_value(:verification_pending) }
        let(:failed_value) { DummyModel.verification_state_value(:verification_failed) }
        let(:succeeded_value) { DummyModel.verification_state_value(:verification_succeeded) }

        it 'includes verification_succeeded with expired checksum' do
          DummyModel.insert_all(
            [
              { verification_state: succeeded_value, verified_at: 15.days.ago }
            ])

          expect(subject.class.needs_reverification.count).to eq 1
        end

        it 'excludes non-success verification states and fresh checksums' do
          DummyModel.insert_all(
            [
              { verification_state: pending_value, verified_at: 7.days.ago },
              { verification_state: failed_value, verified_at: 6.days.ago },
              { verification_state: succeeded_value, verified_at: 3.days.ago }
            ])

          expect(subject.class.needs_reverification.count).to eq 0
        end
      end

      describe '.reverify_batch' do
        let!(:other_verified_records) do
          DummyModel.insert_all(
            [
              { verification_state: succeeded_value, verified_at: 3.days.ago },
              { verification_state: succeeded_value, verified_at: 4.days.ago }
            ])
        end

        let(:succeeded_value) { DummyModel.verification_state_value(:verification_succeeded) }

        before do
          subject.verification_started
          subject.verification_succeeded_with_checksum!('foo', Time.current)

          subject.update!(verified_at: 15.days.ago)
        end

        it 'sets pending status to records with outdated verification' do
          expect do
            expect(subject.class.reverify_batch(batch_size: 100)).to eq 1
          end.to change { subject.reload.verification_pending? }.to be_truthy
        end

        it 'limits the update with batch_size' do
          DummyModel.update_all(verified_at: 15.days.ago)

          expect(subject.class.reverify_batch(batch_size: 2)).to eq 2
          expect(DummyModel.verification_pending.count).to eq 2
        end
      end

      describe '.fail_verification_timeouts' do
        before do
          subject.verification_started!
        end

        context 'when verification has not timed out for a record' do
          it 'does not update verification state' do
            subject.update!(verification_started_at: (described_class::VERIFICATION_TIMEOUT - 1.minute).ago)

            DummyModel.fail_verification_timeouts

            expect(subject.reload.verification_started?).to be_truthy
          end
        end

        context 'when verification has timed out for a record' do
          it 'sets verification state to failed' do
            subject.update!(verification_started_at: (described_class::VERIFICATION_TIMEOUT + 1.minute).ago)

            DummyModel.fail_verification_timeouts

            expect(subject.reload.verification_failed?).to be_truthy
            expect(subject.reload.verification_failure).to eq("Verification timed out after #{described_class::VERIFICATION_TIMEOUT}")
          end

          it 'logs the verification state transition' do
            model_record.update!(verification_started_at: (described_class::VERIFICATION_TIMEOUT + 1.minute).ago)

            expect(Gitlab::Geo::Logger).to receive(:warn).with(
              hash_including(
                message: 'Verification state transition',
                class: DummyModel.verification_state_table_class.name,
                id: model_record.id,
                model_record_id: model_record.id,
                from: 'verification_started',
                to: 'verification_failed',
                result: true
              )
            )

            DummyModel.fail_verification_timeouts
          end
        end
      end

      describe '#track_checksum_attempt!', :aggregate_failures do
        context 'when verification was not yet started' do
          it 'starts verification' do
            expect do
              subject.track_checksum_attempt! do
                'a_checksum_value'
              end
            end.to change { subject.verification_started_at }.from(nil)
          end

          it 'sets verification_succeeded' do
            expect do
              subject.track_checksum_attempt! do
                'a_checksum_value'
              end
            end.to change { subject.verification_succeeded? }.from(false).to(true)
          end
        end

        context 'when verification was started' do
          it 'does not update verification_started_at' do
            subject.verification_started!
            expected = subject.verification_started_at

            subject.track_checksum_attempt! do
              'a_checksum_value'
            end

            expect(subject.verification_started_at).to be_within(1.second).of(expected)
          end
        end

        it 'yields to the checksum calculation' do
          expect do |probe|
            subject.track_checksum_attempt!(&probe)
          end.to yield_with_no_args
        end

        context 'when an error occurs while yielding' do
          context 'when the record was failed' do
            it 'sets verification_failed and increments verification_retry_count' do
              subject.verification_failed_with_message!('foo')

              subject.track_checksum_attempt! do
                raise 'an error'
              end

              expect(subject.reload.verification_failed?).to be_truthy
              expect(subject.verification_retry_count).to eq(2)
            end
          end
        end

        context 'when the yielded block returns nil' do
          context 'when the record was pending' do
            it 'sets verification_failed and sets verification_retry_count to 1' do
              subject.track_checksum_attempt! { nil }

              expect(subject.reload.verification_failed?).to be_truthy
              expect(subject.verification_retry_count).to eq(1)
            end
          end

          context 'when the record was failed' do
            it 'sets verification_failed and increments verification_retry_count' do
              subject.verification_failed_with_message!('foo')

              subject.track_checksum_attempt! { nil }

              expect(subject.reload.verification_failed?).to be_truthy
              expect(subject.verification_retry_count).to eq(2)
            end
          end
        end
      end

      describe '#verification_succeeded_with_checksum!' do
        before do
          subject.verification_started!
        end

        context 'when the resource was updated during checksum calculation' do
          let(:calculation_started_at) { subject.verification_started_at - 1.second }

          it 'sets state to pending' do
            subject.verification_succeeded_with_checksum!('abc123', calculation_started_at)

            expect(subject.reload.verification_pending?).to be_truthy
          end
        end

        context 'when the resource was not updated during checksum calculation' do
          let(:calculation_started_at) { subject.verification_started_at + 1.second }

          it 'saves the checksum' do
            subject.verification_succeeded_with_checksum!('abc123', calculation_started_at)

            expect(subject.reload.verification_succeeded?).to be_truthy
            expect(subject.reload.verification_checksum).to eq('abc123')
            expect(subject.verified_at).not_to be_nil
          end
        end

        context 'primary node' do
          it 'calls replicator.geo_handle_after_checksum_succeeded' do
            stub_current_geo_node(primary_node)

            expect(subject.replicator).to receive(:geo_handle_after_checksum_succeeded)

            subject.verification_succeeded_with_checksum!('abc123', Time.current)
          end
        end

        context 'secondary node' do
          it 'does not call replicator.geo_handle_after_checksum_succeeded' do
            stub_current_geo_node(secondary_node)

            expect(subject.replicator).not_to receive(:geo_handle_after_checksum_succeeded)

            subject.verification_succeeded_with_checksum!('abc123', Time.current)
          end
        end
      end

      describe '#verification_failed_with_message!' do
        it 'saves the error message and increments retry counter' do
          error = double('error', message: 'An error message')

          subject.verification_started!
          subject.verification_failed_with_message!('Failure to calculate checksum', error)

          expect(subject.reload.verification_failed?).to be_truthy
          expect(subject.reload.verification_failure).to eq 'Failure to calculate checksum: An error message'
          expect(subject.verification_retry_count).to be 1
          expect(subject.verification_checksum).to be_nil
        end

        it 'does not raise an error when failure message is too long' do
          error = double('error', message: 'An error message')
          failure = 'Failure to calculate checksum is too long' * 10

          subject.verification_started!

          expect { subject.verification_failed_with_message!(failure, error) }.not_to raise_error

          expect(subject.reload.verification_failed?).to be_truthy
          expect(subject.reload.verification_failure.length).to be 255
          expect(subject.verification_retry_count).to be 1
          expect(subject.verification_checksum).to be_nil
        end

        it 'logs errors in geo.log' do
          original_error = StandardError.new('foo')
          allow(subject).to receive(:verification_failed!).and_raise(StandardError, 'bar')
          subject.verification_started!

          expect(Gitlab::Geo::Logger).to receive(:error).with(hash_including(
            message: 'Error during verification',
            error: 'foo',
            id: subject.id
          ))
          expect(Gitlab::Geo::Logger).to receive(:error).with(hash_including(
            message: 'Error when saving failed verification',
            error: 'bar',
            id: subject.id
          ))
          expect do
            subject.verification_failed_with_message!('Error during verification', original_error)
          end.to raise_error(StandardError, 'bar')
        end
      end

      describe '#verification_started!' do
        it 'flips the state to started state' do
          expect { subject.verification_started! }.to change { subject.verification_state }.from(0).to(1)
        end
      end

      context 'with verification not pending / not disabled' do
        let(:pending) { DummyModel.new }
        let(:started) { DummyModel.new }
        let(:succeeded) { DummyModel.new }
        let(:failed) { DummyModel.new }
        let(:disabled) { DummyModel.new }

        before do
          pending.update!(verification_state: DummyModel.verification_state_value(:verification_pending))
          started.update!(verification_state: DummyModel.verification_state_value(:verification_started))
          succeeded.update!(verification_state: DummyModel.verification_state_value(:verification_succeeded), verification_checksum: 'abc')
          failed.update!(verification_state: DummyModel.verification_state_value(:verification_failed), verification_failure: 'error')
          disabled.update!(verification_state: DummyModel.verification_state_value(:verification_disabled))
        end

        describe '.verification_not_disabled' do
          it 'returns available verifiables, excluding verification_disabled' do
            expect(subject.class.verification_not_disabled).to match_array([pending, started, succeeded, failed])
          end
        end

        describe '.verification_not_pending' do
          it 'returns available verifiables, excluding verification_pending' do
            expect(subject.class.verification_not_pending).to match_array([started, succeeded, failed, disabled])
          end
        end
      end
    end

    context 'when verification state is stored in a separate table' do
      before_all do
        create_dummy_model_with_separate_state_table
      end

      after(:all) do
        drop_dummy_model_with_separate_state_table
      end

      before do
        stub_dummy_replicator_class(model_class: 'TestDummyModelWithSeparateState')
        stub_dummy_model_with_separate_state_class
        stub_dummy_replication_feature_flag
        stub_dummy_verification_feature_flag
      end

      subject(:model_record) { TestDummyModelWithSeparateState.new }

      describe '.fail_verification_timeouts' do
        before do
          state = model_record.verification_state_object
          state.update!(verification_started_at: (described_class::VERIFICATION_TIMEOUT + 1.minute).ago,
            verification_state: 1)
        end

        it 'sets verification state to failed' do
          TestDummyModelWithSeparateState.fail_verification_timeouts

          expect(model_record.reload.verification_failed?).to be_truthy
        end

        it 'logs the verification state transition' do
          expect(Gitlab::Geo::Logger).to receive(:warn).with(
            hash_including(
              message: 'Verification state transition',
              class: TestDummyModelWithSeparateState.verification_state_table_class.name,
              id: Integer,
              model_record_id: anything,
              from: 'verification_started',
              to: 'verification_failed',
              result: true
            )
          )
          TestDummyModelWithSeparateState.fail_verification_timeouts
        end
      end

      describe '#verification_started!' do
        it 'flips the state to started state without reseting/reloading the original object (only state record)' do
          subject.verification_failure = 'draft changes'

          expect { subject.verification_started! }.to change { subject.verification_state }.from(0).to(1)
          expect(subject.verification_failure).to eq('draft changes')
        end
      end

      describe '.needs_verification' do
        it 'includes verification_pending' do
          subject.save!

          expect(subject.class.needs_verification).to include(subject)
        end

        it 'includes verification_failed and verification_retry_due' do
          subject.verification_started
          subject.verification_failed_with_message!('foo')
          subject.update!(verification_retry_at: 1.minute.ago)

          expect(subject.class.needs_verification).to include(subject)
        end

        it 'excludes verification_failed with future verification_retry_at' do
          subject.verification_started
          subject.verification_failed_with_message!('foo')
          subject.update!(verification_retry_at: 1.minute.from_now)

          expect(subject.class.needs_verification).not_to include(subject)
        end
      end

      describe '.needs_reverification' do
        let(:pending_value) { TestDummyModelWithSeparateState.verification_state_value(:verification_pending) }
        let(:failed_value) { TestDummyModelWithSeparateState.verification_state_value(:verification_failed) }
        let(:succeeded_value) { TestDummyModelWithSeparateState.verification_state_value(:verification_succeeded) }

        it 'includes verification_succeeded with expired checksum' do
          model_record.verification_state_object.update!(verification_state: succeeded_value,
            verified_at: 15.days.ago,
            verification_checksum: 'abc')

          expect(subject.class.needs_reverification.first).to eq(model_record)
        end

        it 'excludes non-success verification states and fresh checksums' do
          [pending_value, failed_value, succeeded_value].each_with_index do |state, i|
            state_params = { verification_state: state, verified_at: (i * 3).days.ago }
            state_params = state_params.merge(verification_checksum: 'abc') if state == succeeded_value
            state_params = state_params.merge(verification_failure: 'error') if state == failed_value

            TestDummyModelWithSeparateState.new.update!(state_params)
          end

          expect(subject.class.needs_reverification.count).to eq 0
        end
      end

      context 'with verification not pending / not disabled' do
        let(:pending) { TestDummyModelWithSeparateState.new }
        let(:started) { TestDummyModelWithSeparateState.new }
        let(:succeeded) { TestDummyModelWithSeparateState.new }
        let(:failed) { TestDummyModelWithSeparateState.new }
        let(:disabled) { TestDummyModelWithSeparateState.new }

        before do
          pending.update!(verification_state: TestDummyModelWithSeparateState.verification_state_value(:verification_pending))
          started.update!(verification_state: TestDummyModelWithSeparateState.verification_state_value(:verification_started))
          succeeded.update!(verification_state: TestDummyModelWithSeparateState.verification_state_value(:verification_succeeded), verification_checksum: 'abc')
          failed.update!(verification_state: TestDummyModelWithSeparateState.verification_state_value(:verification_failed), verification_failure: 'error')
          disabled.update!(verification_state: TestDummyModelWithSeparateState.verification_state_value(:verification_disabled))
        end

        describe '.verification_not_disabled' do
          it 'returns available verifiables, excluding verification_disabled' do
            expect(subject.class.verification_not_disabled).to match_array([pending, started, succeeded, failed])
          end
        end

        describe '.verification_not_pending' do
          it 'returns available verifiables, excluding verification_pending' do
            expect(subject.class.verification_not_pending).to match_array([started, succeeded, failed, disabled])
          end
        end
      end
    end
  end

  context 'for registry classes' do
    before do
      stub_current_geo_node(secondary_node)
    end

    shared_context 'with Geo registries' do
      let_it_be(:factory, freeze: true) { :geo_package_file_registry }
      let_it_be(:registry_class) { Geo::PackageFileRegistry }

      let_it_be(:pending_value, freeze: true) { registry_class.verification_state_value(:verification_pending) }
      let_it_be(:failed_value, freeze: true) { registry_class.verification_state_value(:verification_failed) }
      let_it_be(:succeeded_value, freeze: true) { registry_class.verification_state_value(:verification_succeeded) }

      let_it_be(:pending, freeze: true) { create(factory, :synced, verification_state: pending_value) }
      let_it_be(:started, freeze: true) { create(factory, :synced, verification_state: registry_class.verification_state_value(:verification_started)) }

      let_it_be(:succeeded, freeze: true) do
        create(factory, :synced, verification_state: succeeded_value, verification_checksum: 'abc123')
      end

      let_it_be(:failed, freeze: true) do
        create(factory, :synced, verification_state: failed_value, verification_failure: 'Foo bar')
      end
    end

    describe '.fail_verification_timeouts' do
      it 'sets sync state to failed' do
        registry = create(:geo_package_file_registry, :synced, verification_started_at: (described_class::VERIFICATION_TIMEOUT + 1.minute).ago, verification_state: 1)

        registry.class.fail_verification_timeouts

        expect(registry.reload.failed?).to be_truthy
        expect(registry.last_sync_failure).to match(/Verification timed out/)
        expect(registry.retry_count).to eq(1)
        expect(registry.verification_failed?).to be_truthy
        expect(registry.verification_failure).to match(/Verification timed out/)
      end
    end

    describe '.verification_not_disabled' do
      include_context 'with Geo registries'

      it 'returns available verifiables, excluding verification_disabled' do
        # disabled will not be returned
        create(factory, :synced, verification_state: registry_class.verification_state_value(:verification_disabled))

        expect(registry_class.verification_not_disabled).to match_array([pending, started, succeeded, failed])
      end
    end

    describe '.verification_not_pending' do
      include_context 'with Geo registries'

      it 'returns available verifiables, excluding verification_pending' do
        expect(registry_class.verification_not_pending).to match_array([started, succeeded, failed])
      end
    end

    describe '#verification_started!' do
      it 'flips the state to started state' do
        registry = create(:geo_package_file_registry)

        expect { registry.verification_started! }.to change { registry.verification_state }.from(0).to(1)
      end
    end

    describe '.needs_verification' do
      include_context 'with Geo registries'

      let_it_be(:failed_retry_due, freeze: true) do
        create(factory, :synced, verification_state: failed_value, verification_failure: 'Foo bar', verification_retry_at: 1.minute.ago)
      end

      let_it_be(:failed_future_retry_due, freeze: true) do
        create(factory, :synced, verification_state: failed_value, verification_failure: 'Foo bar', verification_retry_at: 1.minute.from_now)
      end

      it 'only includes verification_pending, failed and retry_due in the past' do
        records = registry_class.needs_verification

        expect(records.pluck(:id)).to match_array([pending.id, failed_retry_due.id, failed.id])
        expect(records.size).to eq(3)
      end
    end

    describe '.needs_reverification' do
      include_context 'with Geo registries'

      let_it_be(:outdated_success, freeze: true) do
        create(factory, :synced, verification_state: succeeded_value, verification_checksum: 'abc123', verified_at: 4.months.ago)
      end

      it 'includes verification_succeeded with expired checksum' do
        results = registry_class.needs_reverification

        expect(results.first).to eq(outdated_success)
        expect(results.size).to eq(1)
      end

      it 'excludes non-success verification states and fresh checksums' do
        [pending_value, failed_value, succeeded_value].each_with_index do |state, i|
          state_params = { verification_state: state, verified_at: (i * 3).days.ago }
          state_params = state_params.merge(verification_checksum: 'abc') if state == succeeded_value
          state_params = state_params.merge(verification_failure: 'error') if state == failed_value

          create(factory, :synced, **state_params)
        end

        results = registry_class.needs_reverification

        # There still should be only the one result
        expect(results.first).to eq(outdated_success)
        expect(results.size).to eq(1)
      end
    end
  end
end
