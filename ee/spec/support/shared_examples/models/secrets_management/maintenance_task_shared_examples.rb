# frozen_string_literal: true

RSpec.shared_examples 'a secrets manager maintenance task' do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:root_namespace).class_name('Namespace') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_presence_of(:root_namespace_id) }
    it { is_expected.to validate_numericality_of(:retry_count).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:action).with_values(provision: 0, deprovision: 1) }
  end

  describe '.stale' do
    it 'returns tasks older than the threshold' do
      stale_task = create(factory_name, last_processed_at: 2.hours.ago)
      recent_task = create(factory_name, last_processed_at: 10.minutes.ago)

      results = described_class.stale(1.hour)

      expect(results).to include(stale_task)
      expect(results).not_to include(recent_task)
    end

    it 'respects different threshold values' do
      task = create(factory_name, last_processed_at: 2.hours.ago)

      expect(described_class.stale(3.hours)).not_to include(task)
    end

    it 'does not include tasks with NULL last_processed_at' do
      unprocessed_task = create(factory_name, last_processed_at: nil)

      expect(described_class.stale(1.hour)).not_to include(unprocessed_task)
    end
  end

  describe '.unprocessed' do
    it 'returns only tasks with NULL last_processed_at' do
      unprocessed_task = create(factory_name, last_processed_at: nil)
      processed_task = create(factory_name, last_processed_at: 10.minutes.ago)

      results = described_class.unprocessed

      expect(results).to include(unprocessed_task)
      expect(results).not_to include(processed_task)
    end
  end

  describe '.retryable' do
    it 'returns tasks below the max retry count' do
      retryable_task = create(factory_name, retry_count: 1)
      max_retried_task = create(factory_name, retry_count: 3)

      results = described_class.retryable(3)

      expect(results).to include(retryable_task)
      expect(results).not_to include(max_retried_task)
    end

    it 'respects different max retry values' do
      task = create(factory_name, retry_count: 1)

      expect(described_class.retryable(1)).not_to include(task)
    end
  end

  describe '.processable' do
    it 'returns unprocessed tasks and tasks older than the threshold, but not recently processed ones' do
      unprocessed_task = create(factory_name, last_processed_at: nil)
      stale_task = create(factory_name, last_processed_at: 2.hours.ago)
      recent_task = create(factory_name, last_processed_at: 10.minutes.ago)

      results = described_class.processable(1.hour)

      expect(results).to include(unprocessed_task, stale_task)
      expect(results).not_to include(recent_task)
    end
  end

  describe 'scopes combination' do
    it 'chains stale and retryable scopes correctly' do
      stale_and_retryable = create(factory_name, last_processed_at: 2.hours.ago, retry_count: 1)
      stale_but_max_retries = create(factory_name, last_processed_at: 2.hours.ago, retry_count: 3)

      results = described_class.stale(1.hour).retryable(3)

      expect(results).to include(stale_and_retryable)
      expect(results).not_to include(stale_but_max_retries)
    end
  end
end
