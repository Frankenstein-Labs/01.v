import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AuditEventDetailsPanel from 'ee/agent_artifacts/components/audit_event_details_panel.vue';
import SummarySection from 'ee/agent_artifacts/components/summary_section.vue';
import DetailsSection from 'ee/agent_artifacts/components/details_section.vue';

describe('AuditEventDetailsPanel', () => {
  let wrapper;

  const mockEvent = {
    eventName: 'tool_execution',
    workflowId: '1908',
    details: { input_prompt: 'hello' },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AuditEventDetailsPanel, {
      propsData: {
        event: mockEvent,
        workflowDefinition: 'false_positive_detection/v1',
        ...props,
      },
    });
  };

  const findPanel = () => wrapper.findByTestId('audit-event-details-panel');
  const findTitle = () => wrapper.findByTestId('audit-event-title');
  const findSummarySection = () => wrapper.findComponent(SummarySection);
  const findDetailsSection = () => wrapper.findComponent(DetailsSection);
  const findDownloadSlot = () => wrapper.findByTestId('download-slot-content');

  beforeEach(() => {
    createComponent();
  });

  it('renders the panel', () => {
    expect(findPanel().exists()).toBe(true);
  });

  it('renders the formatted event name as the title', () => {
    expect(findTitle().text()).toBe('Tool execution');
  });

  it('renders the SummarySection with the event', () => {
    expect(findSummarySection().exists()).toBe(true);
    expect(findSummarySection().props('event')).toEqual(mockEvent);
  });

  it('passes the constant target type to the summary section', () => {
    expect(findSummarySection().props('targetType')).toBe('Ai::DuoWorkflows::Workflow');
  });

  it('reconstructs the target details from the raw workflow definition and id', () => {
    expect(findSummarySection().props('targetDetails')).toBe(
      'false_positive_detection/v1 session 1908',
    );
  });

  it('leaves the target details blank when the workflow definition is missing', () => {
    createComponent({ workflowDefinition: '' });

    expect(findSummarySection().props('targetDetails')).toBe('');
  });

  it('renders the DetailsSection with the event details', () => {
    expect(findDetailsSection().exists()).toBe(true);
    expect(findDetailsSection().props('details')).toEqual(mockEvent.details);
  });

  it('renders the download action slot alongside the title', () => {
    wrapper = shallowMountExtended(AuditEventDetailsPanel, {
      propsData: { event: mockEvent, workflowDefinition: 'false_positive_detection/v1' },
      slots: { 'download-action': '<span data-testid="download-slot-content">Download</span>' },
    });

    expect(findDownloadSlot().exists()).toBe(true);
  });
});
