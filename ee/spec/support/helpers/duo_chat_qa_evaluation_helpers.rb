# frozen_string_literal: true

module DuoChatQaEvaluationHelpers
  TMP_REPORT_PATH = "tmp/duo_chat"
  ANTHROPIC_TIMEOUT = 50.seconds
  NUM_THREADS = 10 # Arbitrarily chosen. Adjust as needed.
  THREAD_START_DELAY = 2

  PROMPT = <<~PROMPT

  Human: You are a teacher grading a quiz.
  You are given a question, the context the question is about, and the student's answer.
  You are asked to score the student's answer as either CORRECT or INCORRECT, based on the context.

  <question>
  %<question>s
  </question>

  <context>
  %<context>s
  </context>

  <student_answer>
  %<duo_chat_answer>s
  </student_answer>

  Use the following format to output your answer:

  <format>
  Grade: If the student answer is correct or not. Write CORRECT or INCORRECT
  Explanation: Step-by-step explanation on why a particular grade has been awarded
  </format>

  Grade the student answers based ONLY on their factual accuracy.
  If the student answers the student does not have access to context, the answer is always INCORRECT.
  Ignore differences in punctuation and phrasing between the student answer and true answer.
  It is OK if the student answer contains more information than the true answer,
  as long as it does not contain any conflicting statements.

  Begin!


  Assistant:
  PROMPT

  # This method runs the given question through through GitLab Duo Chat service
  # then asks LLMs (Claude and Vertex as of now) to grade GitLab Duo Chat's response using the given context.
  #
  # @param user [User] The current user authorized to read `issuable` and use GitLab Duo Chat
  # @param issuable [Issue, Epic] The issuable to be used in as GitLab Duo Chat's context
  # @param question [String] The question the user is asking to GitLab Duo Chat
  # @param context [String] The context that will be used by the LLMs during evaluation.
  #                         The context will usually be a JSON serialization of the issuable being asked about.
  def evaluate_without_reference(user, issuable:, question:, context:)
    response = chat(user, issuable, { content: question, cache_response: false, request_id: SecureRandom.uuid })

    result = {
      question: question,
      resource: issuable.to_reference(full: true),
      answer: response[:response_modifier].response_body,
      tools_used: response[:tools_used],
      evaluations: []
    }

    test_prompt = format(PROMPT, {
      question: question,
      context: context,
      duo_chat_answer: result[:answer]
    })

    result[:evaluations].push(evaluate_with_claude(user, test_prompt))
    result[:evaluations].push(evaluate_with_vertex(user, test_prompt))

    result
  end

  def batch_evaluate
    test_results = Queue.new
    test_queue = Queue.new
    test_cases.each { |test_case| test_queue << test_case }

    (1..NUM_THREADS).map do |_|
      sleep(THREAD_START_DELAY) # Do not start all threads immediately.

      Thread.new do
        until test_queue.empty?
          test_case = test_queue.pop
          resource = test_case[:issuable].to_reference(full: true)
          question = test_case[:question]
          puts "Sending the evaluation request for '#{question}' with (#{resource})"

          Sidekiq::Worker.skipping_transaction_check do
            Sidekiq::Testing.fake! do
              test_results << evaluate_without_reference(user, **test_case)
            end
          rescue Net::ReadTimeout => _error
            # Few requests may fail after exceeding the timeout threshold. Ignore them.
          end
        end
      end
    end.each(&:join)

    test_results = Array.new(test_results.size) { test_results.pop }
    save_evaluations(test_results)

    test_results
  end

  def save_evaluations(result)
    save_path = File.join(ENV.fetch('CI_PROJECT_DIR', ''), TMP_REPORT_PATH)
    file_path = File.join(save_path, "qa_#{Time.current.to_i}.json")
    FileUtils.mkdir_p(File.dirname(file_path))

    puts "Saving to #{file_path}"

    File.write(file_path, ::Gitlab::Json.pretty_generate(result))
  end

  def print_evaluation(result)
    puts "----------------------------------------------------"
    puts "------------ Evaluation report (begin) -------------"
    puts "Question: #{result[:question]}\n"
    puts "Resource: #{result[:resource]}\n"
    puts "Tools used: #{result[:tools_used]}\n"
    puts "Chat answer: #{result[:answer]}\n\n"

    result[:evaluations].each do |eval|
      puts "-------------------- Evaluation --------------------"
      puts eval[:model]
      puts eval[:response]
    end

    puts "------------- Evaluation report (end) --------------"
    puts "----------------------------------------------------"
  end

  def evaluate_with_claude(user, test_prompt)
    anthropic_response = Gitlab::Llm::Anthropic::Client.new(user,
      unit_primitive: 'duo_chat').complete(prompt: test_prompt, temperature: 0.1, timeout: ANTHROPIC_TIMEOUT)

    response =
      if anthropic_response&.success?
        anthropic_response['completion']
      else
        warn "Unsuccessful request to Anthropic: #{anthropic_response&.code}"
        nil
      end

    {
      model: Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
      response: response
    }
  end

  def evaluate_with_vertex(user, test_prompt)
    vertex_response = Gitlab::Llm::VertexAi::Client.new(user, unit_primitive: 'duo_chat').text(content: test_prompt)

    response =
      if vertex_response&.success?
        vertex_response.dig("predictions", 0, "content").to_s.strip
      else
        warn "Unsuccessful request to Vertex AI: #{vertex_response&.code}"
        nil
      end

    {
      model: Gitlab::Llm::VertexAi::ModelConfigurations::Text::NAME,
      response: response
    }
  end

  def chat(user, resource, options)
    message_attributes = options.extract!(:content, :request_id, :client_subscription_id).merge(
      user: user,
      context: ::Gitlab::Llm::AiMessageContext.new(resource: resource),
      ai_action: 'chat',
      role: ::Gitlab::Llm::AiMessage::ROLE_USER
    )

    ai_prompt_message = ::Gitlab::Llm::AiMessage.for(action: 'chat').new(message_attributes)
    ai_completion = ::Gitlab::Llm::CompletionsFactory.completion!(ai_prompt_message, options)
    response_modifier = ai_completion.execute

    {
      response_modifier: response_modifier,
      tools_used: ai_completion.context.tools_used
    }
  end
end
