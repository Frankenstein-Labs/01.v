import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import IssueCardTimeInfoEE from 'ee/work_items/list/components/issue_card_time_info.vue';
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import IssueCardTimeInfo from '~/work_items/list/components/issue_card_time_info.vue';
import { stubComponent } from 'helpers/stub_component';
import {
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_ITERATION,
} from '~/work_items/constants';

describe('EE IssueCardTimeInfo component', () => {
  let wrapper;

  const mockIteration = {
    id: 'gid://gitlab/Iteration/1',
    title: 'Iteration 1',
    startDate: '2023-01-01',
    dueDate: '2023-01-14',
    iterationCadence: {
      id: 'gid://gitlab/Iterations::Cadence/1',
      title: 'Monthly Cadence',
    },
  };

  const issueObject = {
    weight: 2,
    healthStatus: 'onTrack',
    iteration: mockIteration,
    namespace: { fullPath: 'gitlab-org/gitlab' },
  };

  const workItemObject = {
    namespace: { fullPath: 'gitlab-org/gitlab' },
    widgets: [
      {
        type: WIDGET_TYPE_HEALTH_STATUS,
        healthStatus: 'onTrack',
      },
      {
        type: WIDGET_TYPE_WEIGHT,
        weight: 2,
      },
      {
        type: WIDGET_TYPE_ITERATION,
        iteration: mockIteration,
      },
    ],
  };

  const findWeightCount = () => wrapper.findComponentByTestId('issuable-weight-content');
  const findIssueHealthStatus = () => wrapper.findComponent(IssueHealthStatus);
  const findIteration = () => wrapper.findComponent(WorkItemIterationAttribute);

  const mountComponent = ({
    issue,
    hasIssuableHealthStatusFeature = false,
    hasIssueWeightsFeature = false,
    hasIterationsFeature = false,
    isWorkItemList = false,
    issueCardTimeInfoStub,
    hiddenMetadataKeys = [],
  } = {}) =>
    shallowMountExtended(IssueCardTimeInfoEE, {
      provide: { hasIssuableHealthStatusFeature, hasIssueWeightsFeature, hasIterationsFeature },
      propsData: { issue, isWorkItemList, hiddenMetadataKeys },
      stubs: issueCardTimeInfoStub,
    });

  describe.each`
    type           | obj
    ${'issue'}     | ${issueObject}
    ${'work item'} | ${workItemObject}
  `('with $type object', ({ obj }) => {
    describe('weight', () => {
      it('renders', () => {
        wrapper = mountComponent({
          issue: obj,
          hasIssueWeightsFeature: true,
          issueCardTimeInfoStub: {
            IssueCardTimeInfo: stubComponent(IssueCardTimeInfo, {
              template: `<div><slot name="weight"></slot></div>`,
            }),
          },
        });

        expect(findWeightCount().props('title')).toBe('2');
      });

      it('hides weight when "weight" is in hiddenMetadataKeys', () => {
        wrapper = mountComponent({
          issue: obj,
          hasIssueWeightsFeature: true,
          hiddenMetadataKeys: ['weight'],
          issueCardTimeInfoStub: {
            IssueCardTimeInfo: stubComponent(IssueCardTimeInfo, {
              template: `<div><slot name="weight"></slot></div>`,
            }),
          },
        });

        expect(findWeightCount().exists()).toBe(false);
      });
    });

    describe('health status', () => {
      describe('when isWorkItemList=true', () => {
        it('does not renders', () => {
          wrapper = mountComponent({
            issue: obj,
            hasIssuableHealthStatusFeature: true,
            isWorkItemList: true,
          });

          expect(findIssueHealthStatus().exists()).toBe(false);
        });
      });

      describe('when isWorkItemList=false', () => {
        it('renders', () => {
          wrapper = mountComponent({
            issue: obj,
            hasIssuableHealthStatusFeature: true,
            isWorkItemList: false,
          });

          expect(findIssueHealthStatus().props('healthStatus')).toBe('onTrack');
        });
      });

      describe('when hasIssuableHealthStatusFeature=true', () => {
        it('renders', () => {
          wrapper = mountComponent({ hasIssuableHealthStatusFeature: true, issue: obj });

          expect(findIssueHealthStatus().props('healthStatus')).toBe('onTrack');
        });
      });

      describe('when hasIssuableHealthStatusFeature=false', () => {
        it('does not render', () => {
          wrapper = mountComponent({ hasIssuableHealthStatusFeature: false, issue: obj });

          expect(findIssueHealthStatus().exists()).toBe(false);
        });
      });
    });
  });

  describe('iteration', () => {
    it('renders', () => {
      wrapper = mountComponent({
        issue: workItemObject,
        hasIterationsFeature: true,
        issueCardTimeInfoStub: {
          IssueCardTimeInfo: stubComponent(IssueCardTimeInfo, {
            template: `<div><slot name="iteration"></slot></div>`,
          }),
        },
      });

      expect(findIteration().exists()).toBe(true);
      expect(findIteration().props('namespacePath')).toBe('gitlab-org/gitlab');
    });

    it('hides iteration when "iteration" is in hiddenMetadataKeys', () => {
      wrapper = mountComponent({
        issue: workItemObject,
        hasIterationsFeature: true,
        hiddenMetadataKeys: ['iteration'],
        issueCardTimeInfoStub: {
          IssueCardTimeInfo: stubComponent(IssueCardTimeInfo, {
            template: `<div><slot name="iteration"></slot></div>`,
          }),
        },
      });

      expect(findIteration().exists()).toBe(false);
    });

    it('does not render when iteration feature is disabled', () => {
      wrapper = mountComponent({ issue: workItemObject, hasIterationsFeature: false });

      expect(findIteration().exists()).toBe(false);
    });

    it('does not render when iteration data is not present', () => {
      wrapper = mountComponent({
        issue: {
          workItemObject: {
            ...workItemObject.widgets.slice(0, -1),
          },
        },
        hasIterationsFeature: true,
      });

      expect(findIteration().exists()).toBe(false);
    });
  });

  describe('multiple hidden metadata fields', () => {
    it('hides both weight and iteration when specified', () => {
      wrapper = mountComponent({
        issue: workItemObject,
        hasIssueWeightsFeature: true,
        hasIterationsFeature: true,
        hiddenMetadataKeys: ['weight', 'iteration'],
        issueCardTimeInfoStub: {
          IssueCardTimeInfo: stubComponent(IssueCardTimeInfo, {
            template: `<div><slot name="weight"></slot><slot name="iteration"></slot></div>`,
          }),
        },
      });

      expect(findWeightCount().exists()).toBe(false);
      expect(findIteration().exists()).toBe(false);
    });
  });
});
