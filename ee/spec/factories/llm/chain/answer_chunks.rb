# frozen_string_literal: true

FactoryBot.define do
  # Creates a mock for Duo Chat answer chunks in next format:
  # { type: "final_answer_delta", data: { text: "chunk1" } }\n
  # { type: "final_answer_delta", data: { text: "chunk2" } }
  factory :final_answer_multi_chunk, class: "String" do
    skip_create

    transient do
      chunks { [] }
    end

    initialize_with do
      chunks.map { |chunk| create(:final_answer_chunk, chunk: chunk) }
            .join("")
    end
  end

  # Creates a single chunk of "final_answer_delta" type
  factory :final_answer_chunk, class: "String" do
    skip_create

    transient do
      chunk { "" }
    end

    initialize_with do
      d = { type: "final_answer_delta", data: { text: chunk } }.to_json
      "#{d}\n"
    end
  end

  # Creates a mock for Duo Chat action answer
  factory :action_chunk, class: "String" do
    skip_create

    transient do
      thought { "Thought: I need to retrieve the issue content using the \"issue_reader\" tool." }
      tool { "issue_reader" }
      tool_input { "what is the title of this issue" }
    end

    initialize_with do
      {
        type: "action",
        data: {
          thought: thought,
          tool: tool,
          tool_input: tool_input
        }
      }.to_json
    end
  end
end
