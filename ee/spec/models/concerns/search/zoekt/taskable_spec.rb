# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Taskable, feature_category: :global_search do
  let(:taskable_class) do
    Class.new(ApplicationRecord) do
      include ::Search::Zoekt::Taskable

      self.table_name = 'p_knowledge_graph_tasks'
    end
  end

  it 'raises a NotImplementedError for methods which should be implemented by model', :aggregate_failures do
    expect { taskable_class.task_iterator }.to raise_error(NotImplementedError)
    expect { taskable_class.determine_task_state(nil) }.to raise_error(NotImplementedError)
    expect { taskable_class.on_tasks_done(nil) }.to raise_error(NotImplementedError)
    expect { taskable_class.per_batch_unique_id }.to raise_error(NotImplementedError)
  end
end
