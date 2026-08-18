# frozen_string_literal: true

RSpec.shared_examples 'code suggestion task' do
  let(:base_url) { ::Gitlab::AiGateway.url }
  let(:endpoint) { "#{base_url}/#{endpoint_path}" }

  it 'returns valid endpoint' do
    expect(task.endpoint).to eq endpoint
  end

  it 'returns body' do
    expect(Gitlab::Json.parse(task.body)).to eq expected_body
  end

  it 'has correct feature_name' do
    expect(task.feature_name).to eq expected_feature_name
  end

  it 'has correct unit_primitive_name' do
    expect(task.unit_primitive_name).to eq expected_unit_primitive_name
  end

  it 'is not disabled' do
    expect(task.feature_disabled?).to eq false
  end
end
