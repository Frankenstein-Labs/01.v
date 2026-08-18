# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ChangesTrackingService, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user)      { create(:user) }
  let_it_be(:project)   { create(:project) }
  let_it_be(:namespace) { project.namespace }

  let(:category) { described_class.name }

  let(:missing_message) { 'No valid vulnerabilities to track' }
  let(:invalid_message) { 'All records must be instances of Vulnerability' }
  let(:tracking_error_message) { 'Internal tracking failed: tracking blew up' }

  let(:metric_keys) do
    %w[
      redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_monthly
      redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_weekly
      redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_monthly
      redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_weekly
      counts.count_total_vulnerability_changed_monthly
      counts.count_total_vulnerability_changed_weekly
      counts.count_total_vulnerability_changed
    ]
  end

  where(:field, :old_value, :new_value) do
    :severity | 'medium' | 'high'
  end

  with_them do
    let(:error) { nil }
    let(:event_name) { "vulnerability_changed" }

    let(:vulnerability) do
      create(:vulnerability, project: project, field => old_value)
    end

    let(:vulnerabilities) { [vulnerability] }

    subject(:service) do
      described_class.new(
        user: user,
        category: category,
        vulnerabilities: vulnerabilities,
        new_value: new_value,
        field: field,
        error: error
      )
    end

    describe '#execute', :clean_gitlab_redis_shared_state do
      context 'when required attributes are missing' do
        let(:service) do
          described_class.new(
            user: nil,
            category: nil,
            vulnerabilities: nil,
            new_value: nil,
            field: nil,
            error: nil
          )
        end

        it 'returns a validation error listing all missing attributes' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Missing required attributes: user, category, vulnerabilities, new_value, field')
        end
      end

      context 'when vulnerabilities are valid' do
        it 'emits a success event and tracks metrics' do
          expect do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:vulnerabilities]).to eq([vulnerability])
          end.to trigger_internal_events(event_name).with(
            category: category,
            project: project,
            namespace: namespace,
            user: user,
            additional_properties: {
              label: "vulnerability_change_#{field}",
              property: "success",
              old_value: old_value.as_json,
              new_value: new_value.as_json,
              vulnerability_id: vulnerability.id,
              field: field.to_s
            }
          ).and increment_usage_metrics(*metric_keys)
        end
      end

      context 'when an error is provided' do
        let(:error) { StandardError.new('external dependency failed') }

        it 'emits an error event and tracks metrics' do
          expect do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:vulnerabilities]).to eq([vulnerability])
          end.to trigger_internal_events(event_name).with(
            category: category,
            project: project,
            namespace: namespace,
            user: user,
            additional_properties: {
              label: "vulnerability_change_#{field}",
              property: "error",
              old_value: old_value.as_json,
              new_value: new_value.as_json,
              error_message: error.message,
              vulnerability_id: vulnerability.id,
              field: field.to_s
            }
          ).and increment_usage_metrics(*metric_keys)
        end
      end

      context 'when an internal error is raised during tracking' do
        before do
          call_count = 0

          allow_next_instance_of(described_class) do |service_instance|
            allow(service_instance).to receive(:track_vulnerability_update) do |*|
              call_count += 1
              raise StandardError, 'tracking blew up' if call_count > 1
            end
          end
        end

        let(:tracked_vulnerability) do
          create(:vulnerability, project: project).tap { |v| v.update!(field => old_value) }
        end

        let(:untracked_vulnerability) do
          create(:vulnerability, project: project).tap { |v| v.update!(field => old_value) }
        end

        let(:vulnerabilities) { [tracked_vulnerability, untracked_vulnerability] }

        it 'returns an error response with partially tracked vulnerabilities' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq(tracking_error_message)
          expect(result.payload[:vulnerabilities]).to eq([tracked_vulnerability])
        end
      end

      context 'when vulnerabilities array is empty' do
        let(:vulnerabilities) { [] }

        it 'returns an error response for missing records' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq(missing_message)
        end
      end

      context 'when records are not all Vulnerability instances' do
        let(:vulnerabilities) { [create(:project)] }

        it 'returns an error response for invalid records' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq(invalid_message)
        end
      end
    end
  end
end
