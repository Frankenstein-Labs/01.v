# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::TaskService, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection) }

  let(:service) { described_class.new }

  before do
    allow(Ai::ActiveContext::Connection).to receive(:active).and_return(connection)
  end

  describe '#create_task' do
    let(:task_class) { instance_double(Class, name: 'TestTask') }

    it 'creates a task with provided params' do
      task = service.create_task(task_class, params: { foo: 'bar' })

      expect(task).to be_persisted
      expect(task.name).to eq('TestTask')
      expect(task.params).to eq({ 'foo' => 'bar' })
      expect(task.status).to eq('pending')
      expect(task.connection).to eq(connection)
    end

    it 'creates a task with depends_on relationship' do
      parent_task = create(:ai_active_context_task, connection: connection)
      task = service.create_task(task_class, depends_on: parent_task)

      expect(task.depends_on).to eq(parent_task)
    end

    it 'defaults params to empty hash' do
      task = service.create_task(task_class)

      expect(task.params).to eq({})
    end
  end

  describe '#create_chain' do
    let(:task1) { instance_double(Class, name: 'Task1') }
    let(:task2) { instance_double(Class, name: 'Task2') }
    let(:task3) { instance_double(Class, name: 'Task3') }

    it 'creates a chain of dependent tasks' do
      chain = service.create_chain(
        [task1, { step: 1 }],
        [task2, { step: 2 }],
        [task3, { step: 3 }]
      )

      expect(chain.name).to eq('Task3')
      expect(chain.depends_on.name).to eq('Task2')
      expect(chain.depends_on.depends_on.name).to eq('Task1')
      expect(chain.depends_on.depends_on.depends_on).to be_nil
    end

    it 'creates chain with tasks without params' do
      chain = service.create_chain(
        task1,
        task2,
        task3
      )

      expect(chain.name).to eq('Task3')
      expect(chain.depends_on.name).to eq('Task2')
      expect(chain.depends_on.depends_on.name).to eq('Task1')
    end

    it 'returns the last task in the chain' do
      last_task = service.create_chain(
        [task1],
        [task2],
        [task3]
      )

      expect(last_task.name).to eq('Task3')
    end
  end
end
