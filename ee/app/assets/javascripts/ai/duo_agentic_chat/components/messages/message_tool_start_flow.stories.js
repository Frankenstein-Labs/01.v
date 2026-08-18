import MessageToolStartFlow from './message_tool_start_flow.vue';

const mockStartFlowToolMessage = {
  status: 'success',
  content:
    'Started flow **fix_pipeline/v1** (workflow ID: 326) — [View session](https://example.com/gitlab-duo/test/-/automate/agent-sessions/326)',
  timestamp: '2026-03-26T12:49:34.958100+00:00',
  tool_info: {
    args: {
      goal: 'https://example.com/gitlab-duo/test/-/pipelines/1251',
      inputs: {
        'pipeline.source_branch': 'duo-edit-20260305-174345',
      },
      workflow_definition: 'fix_pipeline/v1',
    },
    name: 'start_flow',
    tool_response: {
      id: null,
      name: 'start_flow',
      type: 'ToolMessage',
      status: 'success',
      content:
        '{"status": "started", "workflow_id": 326, "session_url": "https://example.com/gitlab-duo/test/-/automate/agent-sessions/326", "flow_name": "fix_pipeline/v1"}',
      artifact: null,
      tool_call_id: 'toolu_01UHJB96arU3umrDSbxeFW7H',
      additional_kwargs: {},
      response_metadata: {},
    },
  },
  message_id: 'toolu_01UHJB96arU3umrDSbxeFW7H',
  message_type: 'tool',
  correlation_id: null,
  message_sub_type: 'start_flow',
  additional_context: null,
};

const withStatus = (status) => ({
  ...mockStartFlowToolMessage,
  tool_info: {
    ...mockStartFlowToolMessage.tool_info,
    tool_response: {
      ...mockStartFlowToolMessage.tool_info.tool_response,
      content: JSON.stringify({
        status,
        workflow_id: 324,
        session_url: 'https://example.com/duo/test/-/automate/agent-sessions/324',
        flow_name: 'fix_pipeline/v1',
      }),
    },
  },
});

const Template = (_, { argTypes }) => {
  return {
    components: { MessageToolStartFlow },
    props: Object.keys(argTypes),
    template: '<message-tool-start-flow :message="message" />',
  };
};

export default {
  component: MessageToolStartFlow,
  title: 'ee/ai/duo_agentic_chat/message_tool_start_flow',
};

export const Created = Template.bind({});
Created.args = { message: withStatus('created') };

export const Running = Template.bind({});
Running.args = { message: withStatus('running') };

export const Paused = Template.bind({});
Paused.args = { message: withStatus('paused') };

export const Finished = Template.bind({});
Finished.args = { message: withStatus('finished') };

export const Stopped = Template.bind({});
Stopped.args = { message: withStatus('stopped') };

export const InputRequired = Template.bind({});
InputRequired.args = { message: withStatus('input_required') };

export const PlanApprovalRequired = Template.bind({});
PlanApprovalRequired.args = { message: withStatus('plan_approval_required') };

export const ToolCallApprovalRequired = Template.bind({});
ToolCallApprovalRequired.args = { message: withStatus('tool_call_approval_required') };

export const Failed = Template.bind({});
Failed.args = { message: withStatus('failed') };
