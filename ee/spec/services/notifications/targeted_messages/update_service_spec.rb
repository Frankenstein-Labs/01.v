# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessages::UpdateService, feature_category: :acquisition do
  describe '#execute' do
    let_it_be_with_reload(:targeted_message) { create(:targeted_message) }

    subject(:execute) { described_class.new(targeted_message, targeted_message_params).execute }

    context 'when targeted message param is valid' do
      let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
      let(:invalid_namespace_ids) { [] }
      let(:targeted_message_params) { targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
      let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
      let(:temp_file) do
        temp_file = Tempfile.new(%w[namespace_ids csv])
        temp_file.write(csv_content)
        temp_file.rewind

        temp_file
      end

      let(:csv_file) { fixture_file_upload(temp_file.path, 'text/csv') }

      after do
        temp_file.unlink
      end

      it 'returns a success service response' do
        expect(execute).to be_success
        expect(execute.payload).to be_a(Notifications::TargetedMessage)
      end

      context 'with invalid namespace ids' do
        let(:invalid_namespace_ids) { [non_existing_record_id] }

        it 'returns a error service response warning about invalid namespace ids' do
          partial_success_message = "Targeted message was successfully updated. But the following namespace ids " \
            "were invalid and have been ignored: #{invalid_namespace_ids.join(', ')}"

          expect(execute).to be_error
          expect(execute.message).to eq(partial_success_message)
          expect(execute.reason).to eq(described_class::FOUND_INVALID_NAMESPACES)
        end
      end

      context 'with no valid namespace ids' do
        let(:csv_content) { non_existing_record_id.to_s }

        it 'returns an error service response' do
          expect(execute).to be_error
          expect(execute.payload.errors.full_messages)
            .to include(s_('TargetedMessages|Must have at least one targeted namespace'))
        end
      end

      context 'with new set of targeted message namespace ids' do
        it 'replaces targeted namespaces with new set' do
          execute

          expect(targeted_message.reload.targeted_message_namespaces.map(&:namespace_id))
            .to match_array(targeted_namespace_ids)
        end
      end

      context 'when no csv file is provided' do
        let(:targeted_message_params) { { target_type: targeted_message.target_type } }

        it 'returns a success service response' do
          expect(execute).to be_success
          expect(execute.payload).to be_a(Notifications::TargetedMessage)
        end

        it 'preserves existing targeted message namespaces' do
          expect { execute }.not_to change { targeted_message.reload.targeted_message_namespaces.count }
        end

        context 'when targeted message becomes invalid after assignment' do
          let(:targeted_message_params) { { target_type: '' } }

          it 'returns an error service response' do
            expect(execute).to be_error
            expect(execute.payload.errors.full_messages).to include('Target type can\'t be blank')
          end
        end

        context 'when starts_at is in the past' do
          let(:targeted_message_params) { { starts_at: 1.hour.ago } }

          it 'returns an error service response' do
            expect(execute).to be_error
            expect(execute.payload.errors.full_messages).to include('Starts at cannot be in the past')
          end
        end

        context 'when starts_at is after ends_at' do
          let(:targeted_message_params) { { starts_at: 3.hours.from_now, ends_at: 2.hours.from_now } }

          it 'returns an error service response' do
            expect(execute).to be_error
            expect(execute.payload.errors.full_messages).to include('Starts at must be before ends at')
          end
        end
      end
    end

    context 'when targeted message is invalid' do
      let(:targeted_message_params) { { target_type: '', namespace_ids_csv: 'stubbed file' } }

      it 'returns an error service response' do
        expect(execute).to be_error
        expect(execute.payload.errors.full_messages).to include('Target type can\'t be blank')
      end

      it 'returns a error service response with the csv parsing error added to targeted message' do
        allow_next_instance_of(Notifications::TargetedMessages::NamespaceIdsBuilder) do |builder|
          allow(builder).to receive(:build).and_return({
            valid_namespace_ids: [],
            invalid_namespace_ids: [],
            success: false,
            message: 'CSV parse error'
          })
        end

        expect(execute).to be_error
        expect(execute.payload.errors.full_messages).to include("CSV parse error")
      end
    end
  end
end
