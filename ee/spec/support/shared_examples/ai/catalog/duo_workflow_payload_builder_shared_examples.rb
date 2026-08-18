# frozen_string_literal: true

RSpec.shared_examples 'builds valid flow configuration' do
  it 'returns correct flow configuration structure' do
    expect(result).to include(
      'version' => version,
      'environment' => environment,
      'components' => be_an(Array),
      'routers' => be_an(Array),
      'flow' => be_a(Hash),
      'prompts' => be_an(Array)
    )
  end

  it 'builds components with correct structure' do
    expect(result['components']).to all(include(
      'name' => be_a(String),
      'type' => 'AgentComponent',
      'prompt_id' => match(/.*_prompt$/),
      'inputs' => be_an(Array),
      'toolset' => be_an(Array)
    ))
  end

  it 'builds prompts with correct structure' do
    expect(result['prompts']).to all(include(
      'prompt_id' => match(/.*_prompt$/),
      'prompt_template' => include(
        'system' => be_a(String),
        'user' => be_a(String),
        'placeholder' => be_a(String)
      ),
      'params' => include('timeout' => be_an(Integer))
    ))
  end

  it 'ensures components and prompts have matching prompt_ids' do
    component_prompt_ids = result['components'].pluck('prompt_id')
    prompt_ids = result['prompts'].pluck('prompt_id')

    expect(component_prompt_ids).to match_array(prompt_ids)
  end
end

RSpec.shared_examples 'invalid flow configuration' do
  it 'raises error during build' do
    expect { builder.build }.to raise_error(StandardError)
  end
end
