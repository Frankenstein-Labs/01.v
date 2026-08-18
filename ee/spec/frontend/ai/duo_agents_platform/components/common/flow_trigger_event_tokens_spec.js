import { shallowMount } from '@vue/test-utils';
import { GlToken } from '@gitlab/ui';
import FlowTriggerEventTokens from 'ee/ai/duo_agents_platform/components/common/flow_trigger_event_tokens.vue';
import { buildPipelineHooksFilter } from 'ee_jest/ai/duo_agents_platform/mock_data';

describe('FlowTriggerEventTokens', () => {
  let wrapper;

  const createComponent = (flowTrigger) => {
    wrapper = shallowMount(FlowTriggerEventTokens, {
      propsData: { flowTrigger },
    });
  };

  const findTokens = () => wrapper.findAllComponents(GlToken);
  const tokenTexts = () => findTokens().wrappers.map((token) => token.text());

  it('renders one token per event type using the base label', () => {
    createComponent({ eventTypes: [0, 1], filter: {} });

    expect(tokenTexts()).toEqual(['Mention', 'Assign']);
  });

  it('appends pipeline statuses to the pipeline events token', () => {
    createComponent({
      eventTypes: [3],
      filter: buildPipelineHooksFilter({ value: ['failed', 'canceled'] }),
    });

    expect(tokenTexts()).toEqual(['Pipeline events (Failed, Canceled)']);
  });

  it('appends the configured action to the work item token', () => {
    createComponent({
      eventTypes: [7],
      filter: { work_item: { rules: [{ field: 'action', operator: 'in', value: ['created'] }] } },
    });

    expect(tokenTexts()).toEqual(['Work item (Created)']);
  });

  it('names commit_to_default_branch (8) rather than mislabelling it', () => {
    createComponent({ eventTypes: [8], filter: {} });

    expect(tokenTexts()).toEqual(['Commit to default branch']);
  });

  describe('merge request folding', () => {
    it('folds merge_request_ready (4) into a "Merge request (Marked ready)" token', () => {
      createComponent({ eventTypes: [4], filter: {} });

      expect(tokenTexts()).toEqual(['Merge request (Marked ready)']);
    });

    it('folds merge_request_code_conflict (5) into a "Merge request (Merge conflict)" token', () => {
      createComponent({ eventTypes: [5], filter: {} });

      expect(tokenTexts()).toEqual(['Merge request (Merge conflict)']);
    });

    it('renders a bare "Merge request" token for merge_request (6) with no action filter', () => {
      createComponent({ eventTypes: [6], filter: {} });

      expect(tokenTexts()).toEqual(['Merge request']);
    });

    it('lists the configured actions for merge_request (6)', () => {
      createComponent({
        eventTypes: [6],
        filter: {
          merge_request: {
            rules: [{ field: 'action', operator: 'in', value: ['ready', 'approved'] }],
          },
        },
      });

      expect(tokenTexts()).toEqual(['Merge request (Approved, Marked ready)']);
    });

    it('collapses event types 4, 5, and 6 into a single token', () => {
      createComponent({
        eventTypes: [4, 5, 6],
        filter: {
          merge_request: { rules: [{ field: 'action', operator: 'in', value: ['approved'] }] },
        },
      });

      expect(tokenTexts()).toEqual(['Merge request (Approved, Merge conflict, Marked ready)']);
    });
  });

  it('renders an "Unknown" token for an unrecognized event type', () => {
    createComponent({ eventTypes: [99], filter: {} });

    expect(tokenTexts()).toEqual(['Unknown']);
  });

  it('renders no tokens when there are no event types', () => {
    createComponent({ eventTypes: [], filter: {} });

    expect(findTokens()).toHaveLength(0);
  });

  it('renders no tokens when eventTypes is missing', () => {
    createComponent({});

    expect(findTokens()).toHaveLength(0);
  });
});
