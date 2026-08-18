import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemAiWidget from 'ee/work_items/components/ai_widget/work_item_ai_widget.vue';
import WorkItemConfidenceScore from 'ee/work_items/components/ai_widget/work_item_confidence_score.vue';
import WorkPlan from 'ee/work_items/components/ai_widget/work_plan.vue';
import { AGENT_PLAN_PANEL } from '~/work_items/constants';

describe('WorkItemAiWidget', () => {
  let wrapper;

  const workItem = { id: 'gid://gitlab/WorkItem/1' };

  const createComponent = ({ props = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(WorkItemAiWidget, {
      propsData: { workItem, ...props },
      provide: { glFeatures },
    });
  };

  const findConfidenceScore = () => wrapper.findComponent(WorkItemConfidenceScore);
  const findWorkPlan = () => wrapper.findComponent(WorkPlan);

  it('always renders the work plan child', () => {
    createComponent();
    expect(findWorkPlan().exists()).toBe(true);
  });

  it('forwards props to the work plan child', () => {
    createComponent({
      props: { canUpdate: true, workItemWebUrl: '/url', isInDrawer: true, isPanelOpen: true },
    });
    expect(findWorkPlan().props()).toMatchObject({
      workItem,
      canUpdate: true,
      workItemWebUrl: '/url',
      isInDrawer: true,
      isPanelOpen: true,
    });
  });

  it('re-emits request-panel from the work plan child', () => {
    createComponent();
    findWorkPlan().vm.$emit('request-panel', AGENT_PLAN_PANEL);
    expect(wrapper.emitted('request-panel')).toEqual([[AGENT_PLAN_PANEL]]);
  });

  describe('readiness score', () => {
    describe('when the workplanScore feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({ glFeatures: { workplanScore: false } });
      });

      it('does not render the score', () => {
        expect(findConfidenceScore().exists()).toBe(false);
      });
    });

    describe('when the workplanScore feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({ glFeatures: { workplanScore: true } });
      });

      it('renders the score', () => {
        expect(findConfidenceScore().exists()).toBe(true);
      });

      it('passes a numeric score to the score component', () => {
        expect(typeof findConfidenceScore().props('score')).toBe('number');
      });
    });
  });
});
