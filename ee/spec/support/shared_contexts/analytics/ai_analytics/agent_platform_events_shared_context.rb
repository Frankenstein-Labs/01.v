# frozen_string_literal: true

RSpec.shared_context 'with ai agent platform events' do
  before do
    clickhouse_fixture(:ai_usage_events, [
      # Session 1 - chat flow - created event
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 1,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 10.seconds
      },
      # Session 1 - chat flow - started event
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 1,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 20.seconds
      },
      # Session 1 - chat flow - finished event
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 1,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 30.seconds
      },

      # Session 2 - fix_pipeline flow - created event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 2,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: to - 3.days
      },
      # Session 2 - fix_pipeline flow - started event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 2,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 3.days) + 10.seconds
      },
      # Session 2 - fix_pipeline flow - finished event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 2,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: to - 2.days
      },

      # Session 3 - fix_pipeline flow - created event
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 3,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: to - 2.days
      },
      # Session 3 - fix_pipeline flow - started event
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 3,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 2.days) + 5.seconds
      },
      # Session 3 - fix_pipeline flow - dropped event (no finished)
      {
        user_id: user1.id,
        namespace_path: group.traversal_path(with_organization: false),
        event: 20, # dropped
        extras: {
          session_id: 3,
          flow_type: 'fix_pipeline',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 2.days) + 30.seconds
      },

      # Session 4 - code_review flow - created event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 4,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: to - 2.days
      },
      # Session 4 - code_review flow - started event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 4,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 2.days) + 3.seconds
      },
      # Session 4 - code_review flow - finished event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 4,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 2.days) + 120.seconds
      },

      # Session 5 - code_review flow - outside timeframe - created event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 5,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: to - 6.days
      },
      # Session 5 - code_review flow - started event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 5,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 6.days) + 5.seconds
      },
      # Session 5 - code_review flow - finished event
      {
        user_id: user2.id,
        namespace_path: project_namespace.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 5,
          flow_type: 'code_review',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: (to - 6.days) + 90.seconds
      },

      # Session 6 - chat flow in subgroup - created event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 6,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 10.seconds
      },
      # Session 6 - chat flow in subgroup - started event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 6,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 20.seconds
      },
      # Session 6 - chat flow in subgroup - finished event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 6,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 40.seconds
      },
      # Session 7 - chat flow in subgroup - created event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 8, # created
        extras: {
          session_id: 7,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 10.seconds
      },
      # Session 7 - chat flow in subgroup - started event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 9, # started
        extras: {
          session_id: 7,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 15.seconds
      },
      # Session 7 - chat flow in subgroup - finished event
      {
        user_id: user1.id,
        namespace_path: subgroup.traversal_path(with_organization: false),
        event: 19, # finished
        extras: {
          session_id: 7,
          flow_type: 'chat',
          project_id: project.id,
          environment: 'production'
        }.to_json,
        timestamp: from + 1.day
      }
    ])
  end
end
