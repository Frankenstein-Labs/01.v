# frozen_string_literal: true

RSpec.shared_examples 'with secure type all' do |described_class, builds_table_name, column_name, params|
  let(:secure_type) { 'all' }
  let(:build_names) { "(#{described_class::SECURE_PRODUCT_TYPES.map { |e| "'#{e}'" }.join(', ')})" }
  let(:expected_query) do
    if params[:time_frame] == '28d'
      <<~SQL.squish
      SELECT
        COUNT(DISTINCT "#{builds_table_name}"."#{column_name}")
      FROM
        "#{builds_table_name}"
      WHERE
        "#{builds_table_name}"."type" = 'Ci::Build'
        AND "#{builds_table_name}"."created_at" BETWEEN '#{start}'
        AND '#{finish}'
        AND "#{builds_table_name}"."name" IN #{build_names}
      SQL
    else
      <<~SQL.squish
      SELECT
        COUNT(DISTINCT "#{builds_table_name}"."#{column_name}")
      FROM
        "#{builds_table_name}"
      WHERE
        "#{builds_table_name}"."type" = 'Ci::Build'
        AND "#{builds_table_name}"."name" IN #{build_names}
      SQL
    end
  end

  it_behaves_like 'a correct instrumented metric value and query',
    { time_frame: params[:time_frame], data_source: 'database', options: { secure_type: 'all' } }
end

RSpec.shared_examples 'with secure type' do |secure_type, params|
  let(:secure_type) { secure_type }
  it_behaves_like "a correct instrumented metric value and query",
    { time_frame: params[:time_frame], data_source: 'database', options: { secure_type: secure_type } }
end

RSpec.shared_examples 'with time_frame all' do |builds_table_name, column_name|
  let(:expected_query) do
    <<~SQL.squish
    SELECT
      COUNT(DISTINCT \"#{builds_table_name}\".\"#{column_name}\")
    FROM
      \"#{builds_table_name}\"
    WHERE
      \"#{builds_table_name}\".\"type\" = 'Ci::Build'
      AND \"#{builds_table_name}\".\"name\" = '#{secure_type}'
    SQL
  end

  it_behaves_like 'a correct secure type instrumented metric value', { time_frame: 'all', expected_value: 2 }
end

RSpec.shared_examples 'with time_frame 28d' do |builds_table_name, column_name, db|
  let(:start) { 30.days.ago.to_fs(db) }
  let(:finish) { 2.days.ago.to_fs(db) }
  let(:expected_query) do
    <<~SQL.squish
    SELECT
      COUNT(DISTINCT \"#{builds_table_name}\".\"#{column_name}\")
    FROM
      \"#{builds_table_name}\"
    WHERE
      \"#{builds_table_name}\".\"type\" = 'Ci::Build'
      AND \"#{builds_table_name}\".\"created_at\" BETWEEN '#{start}'
      AND '#{finish}'
      AND \"#{builds_table_name}\".\"name\" = '#{secure_type}'
    SQL
  end

  it_behaves_like 'a correct secure type instrumented metric value', { time_frame: '28d', expected_value: 1 }
end

RSpec.shared_examples 'with exception handling' do
  it 'raises an exception if secure_type option is not present' do
    expect do
      described_class.new(time_frame: 'all')
    end.to raise_error(ArgumentError, /secure_type options attribute is required/)
  end

  it 'raises an exception if secure_type option is invalid' do
    expect do
      described_class.new(options: { secure_type: 'invalid_type' }, time_frame: 'all')
    end.to raise_error(ArgumentError, /Attribute: invalid_type is not allowed/)
  end
end

RSpec.shared_examples 'with cache' do |described_class, cache_id, comp_class|
  context 'with cache_start_and_finish_as called' do
    before do
      allow_next_instance_of(Gitlab::Database::BatchCounter) do |batch_counter|
        allow(batch_counter).to receive(:transaction_open?).and_return(false)
      end
    end

    it 'caches using the key name passed', :request_store, :use_clean_rails_redis_caching do
      metric = "metric_instrumentation/#{cache_id}_%s_id"
      expect(Gitlab::Cache).to receive(:fetch_once).with(
        metric % 'minimum', any_args).and_call_original
      expect(Gitlab::Cache).to receive(:fetch_once).with(
        metric % 'maximum', any_args).and_call_original

      described_class.new(time_frame: 'all', options: { secure_type: 'container_scanning' }).value

      expect(Rails.cache.read(metric % 'minimum')).to eq(comp_class.minimum(:id))
      expect(Rails.cache.read(metric % 'maximum')).to eq(comp_class.maximum(:id))
    end
  end
end
