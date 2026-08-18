# frozen_string_literal: true

RSpec.shared_context 'with text examples' do
  let(:text_examples) do
    {
      'Hello' => 'Hello World',
      '一二' => 'This is a test for Chinese characters 一二三',
      '所有' => '在最新成功的流水线中，保留所有作业的最新产物',
      '写' => '明天你是否会想起，昨天你写的日记。明天你是否还惦记，曾经最爱哭的你。'
    }
  end
end
