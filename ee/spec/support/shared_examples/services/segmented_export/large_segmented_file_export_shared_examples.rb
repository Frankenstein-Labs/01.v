# frozen_string_literal: true

RSpec.shared_examples 'large segmented file export' do
  let(:connection) { export.class.connection }
  let(:transactions_involved) { [] }

  describe 'uploading the file inside of a database transaction' do
    before do
      allow_next_instance_of(AttachmentUploader.storage) do |storage|
        allow(storage).to receive(:store!).and_wrap_original do |original, *args|
          transactions_involved << connection.current_transaction

          original.call(*args)
        end
      end
    end

    it 'does not upload the file inside of a database transaction other than the spec transaction' do
      expect { subject }.to change { transactions_involved }.to([connection.current_transaction])
    end
  end
end
