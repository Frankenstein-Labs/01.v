# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Doctor::Secrets, feature_category: :shared do
  let!(:cloud_connector_key) { create(:cloud_connector_keys) }
  let(:logger) { instance_double(Logger).as_null_object }

  subject(:doctor_secrets) { described_class.new(logger).run! }

  before do
    allow(Gitlab::Runtime).to receive(:rake?).and_return(true)
  end

  context 'when encrypted attributes are properly set' do
    it 'detects decryptable secrets' do
      expect(logger).to receive(:info).with(/CloudConnector::Keys failures: 0/)
      expect(logger).to receive(:info).with(/User failures: 0/)
      expect(logger).to receive(:info).with(/Group failures: 0/)

      doctor_secrets
    end
  end

  context 'when Active Record Encryption values are not decrypting' do
    it 'marks undecryptable values as bad' do
      # We update the attribute at the db-level directly to bypass encryption which happens at type-casting time
      CloudConnector::Keys.connection.execute(
        "UPDATE #{CloudConnector::Keys.table_name} SET secret_key = '{}' WHERE id = #{cloud_connector_key.id}")
      expect(logger).to receive(:info).with(/CloudConnector::Keys failures: 1/)

      doctor_secrets
    end
  end
end
