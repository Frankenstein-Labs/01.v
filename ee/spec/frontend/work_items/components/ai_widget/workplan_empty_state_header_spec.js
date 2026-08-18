import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkplanEmptyStateHeader from 'ee/work_items/components/ai_widget/workplan_empty_state_header.vue';
import ReviewWorkplanEmptyState from 'ee/work_items/components/ai_widget/review_workplan_empty_state.vue';
import GenerateWorkplanEmptyState from 'ee/work_items/components/ai_widget/generate_workplan_empty_state.vue';
import { eventHub, OPEN_AGENT_PLAN_PANEL } from 'ee/ai/events/panel';

const RESOURCE_ID = 'gid://gitlab/WorkItem/1';
const WORK_ITEM_WEB_URL = 'http://gdk.test/gitlab-org/gitlab/-/work_items/1';

describe('WorkplanEmptyStateHeader', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(WorkplanEmptyStateHeader, {
      propsData: { resourceId: RESOURCE_ID, workItemWebUrl: WORK_ITEM_WEB_URL, ...props },
    });
  };

  const findReviewState = () => wrapper.findComponent(ReviewWorkplanEmptyState);
  const findGenerateState = () => wrapper.findComponent(GenerateWorkplanEmptyState);

  describe('when no workplan exists', () => {
    beforeEach(() => {
      createComponent({ props: { hasExistingWorkplan: false } });
    });

    it('renders the generate state and not the review state', () => {
      expect(findGenerateState().exists()).toBe(true);
      expect(findReviewState().exists()).toBe(false);
    });

    it('passes the resource id to the generate state', () => {
      expect(findGenerateState().props('resourceId')).toBe(RESOURCE_ID);
    });

    it('passes the work item web url to the generate state', () => {
      expect(findGenerateState().props('workItemWebUrl')).toBe(WORK_ITEM_WEB_URL);
    });

    describe('when the generate state requests the workplan', () => {
      let openPanelSpy;

      beforeEach(() => {
        openPanelSpy = jest.fn();
        eventHub.$on(OPEN_AGENT_PLAN_PANEL, openPanelSpy);
        findGenerateState().vm.$emit('generate-workplan');
      });

      afterEach(() => {
        eventHub.$off(OPEN_AGENT_PLAN_PANEL, openPanelSpy);
      });

      it('opens the agent plan panel', () => {
        expect(openPanelSpy).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe('when a workplan exists', () => {
    beforeEach(() => {
      createComponent({ props: { hasExistingWorkplan: true } });
    });

    it('renders the review state and not the generate state', () => {
      expect(findReviewState().exists()).toBe(true);
      expect(findGenerateState().exists()).toBe(false);
    });

    describe('when the review state requests the workplan', () => {
      let openPanelSpy;

      beforeEach(() => {
        openPanelSpy = jest.fn();
        eventHub.$on(OPEN_AGENT_PLAN_PANEL, openPanelSpy);
        findReviewState().vm.$emit('review-workplan');
      });

      afterEach(() => {
        eventHub.$off(OPEN_AGENT_PLAN_PANEL, openPanelSpy);
      });

      it('opens the agent plan panel', () => {
        expect(openPanelSpy).toHaveBeenCalledTimes(1);
      });
    });
  });
});
