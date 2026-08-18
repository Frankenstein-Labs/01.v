# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::ErrorClassifier, feature_category: :audit_events do
  using RSpec::Parameterized::TableSyntax

  describe '.log_only?' do
    context 'with user-config errors' do
      # Assert every entry in USER_CONFIG_ERRORS classifies as log-only so a
      # future removal from the list fails a test rather than silently paging
      # Sentry for a non-actionable user-config error.
      where(:error_class) { described_class::USER_CONFIG_ERRORS }

      with_them do
        it 'returns true' do
          error = instance_double(StandardError).tap do |double|
            allow(double).to receive(:is_a?).and_return(false)
            allow(double).to receive(:is_a?).with(error_class).and_return(true)
          end

          expect(described_class.log_only?(error, 'http')).to be(true)
        end
      end
    end

    it 'returns true for GCP errors (log_only category)' do
      expect(described_class.log_only?(StandardError.new, 'gcp')).to be(true)
    end

    it 'returns false for a generic GitLab-side error on http' do
      expect(described_class.log_only?(StandardError.new, 'http')).to be(false)
    end

    it 'returns false for an unknown category' do
      expect(described_class.log_only?(StandardError.new, 'unknown')).to be(false)
    end
  end
end
