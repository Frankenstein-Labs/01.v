import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import TasksByTypeFilters from 'ee/analytics/cycle_analytics/components/tasks_by_type/filters.vue';
import {
  TASKS_BY_TYPE_SUBJECT_ISSUE,
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
} from 'ee/analytics/cycle_analytics/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert, VARIANT_INFO } from '~/alert';
import getTasksByTypeLabels from 'ee/analytics/cycle_analytics/graphql/queries/get_tasks_by_type_labels.query.graphql';
import {
  mockLabels,
  mockLabelsResponse,
  createMockLabelsResponse,
} from '../../vsa_settings/mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

describe('TasksByTypeFilters', () => {
  let wrapper = null;

  const createWrapper = async ({
    props = {},
    labelsResolver = jest.fn().mockResolvedValue(mockLabelsResponse),
  } = {}) => {
    const store = new Vuex.Store({
      state: {
        groupPath: 'groupPath',
      },
    });

    const apolloProvider = createMockApollo([[getTasksByTypeLabels, labelsResolver]]);

    wrapper = shallowMountExtended(TasksByTypeFilters, {
      store,
      apolloProvider,
      propsData: {
        selectedLabelNames: [],
        subjectFilter: TASKS_BY_TYPE_SUBJECT_ISSUE,
        ...props,
      },
    });

    jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    await waitForPromises();
  };

  const findSubjectFilters = () => wrapper.findComponentByTestId('type-of-work-filters-subject');
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectedLabelsCount = () => wrapper.findByTestId('selected-labels-count');

  describe('with default props', () => {
    beforeEach(() => {
      return createWrapper();
    });

    it('has the issue subject set by default', () => {
      expect(findSubjectFilters().props().value).toBe(TASKS_BY_TYPE_SUBJECT_ISSUE);
    });

    it('does not render the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().exists()).toBe(false);
    });

    it('emits the `set-subject` event when a subject filter is clicked', () => {
      expect(wrapper.emitted('set-subject')).toBeUndefined();

      findSubjectFilters().vm.$emit('input', TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);

      expect(wrapper.emitted('set-subject')).toHaveLength(1);
      expect(wrapper.emitted('set-subject')[0][0]).toEqual(TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);
    });

    it('emits the `toggle-label` event when a label is selected', () => {
      expect(wrapper.emitted('toggle-label')).toBeUndefined();

      findCollapsibleListbox().vm.$emit('select', [mockLabels[0].title]);

      expect(wrapper.emitted('toggle-label')).toHaveLength(1);
      expect(wrapper.emitted('toggle-label')[0][0]).toEqual(mockLabels[0]);
      expect(mockAlertDismiss).not.toHaveBeenCalled();
    });
  });

  describe('with one label selected', () => {
    beforeEach(() => {
      return createWrapper({ props: { selectedLabelNames: [mockLabels[0].title] } });
    });

    it('renders the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().text()).toBe('1 label selected (15 max)');
    });
  });

  describe('with maximum labels selected', () => {
    const selectedLabelNames = [mockLabels[0].title, mockLabels[1].title];

    beforeEach(() => {
      return createWrapper({ props: { maxLabels: 2, selectedLabelNames } });
    });

    it('should not allow adding a label', () => {
      findCollapsibleListbox().vm.$emit('select', [...selectedLabelNames, mockLabels[2].title]);
      expect(wrapper.emitted('toggle-label')).toBeUndefined();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Only 2 labels can be selected at this time',
        variant: VARIANT_INFO,
      });
      expect(mockAlertDismiss).not.toHaveBeenCalled();
    });

    it('should allow removing a label', () => {
      findCollapsibleListbox().vm.$emit('select', [mockLabels[0].title]);
      expect(wrapper.emitted('toggle-label')).toHaveLength(1);
      expect(wrapper.emitted('toggle-label')[0][0]).toEqual(mockLabels[1]);
    });

    it('should dismiss maximum labels alert upon removing a label', () => {
      findCollapsibleListbox().vm.$emit('select', [...selectedLabelNames, mockLabels[2].title]);
      expect(createAlert).toHaveBeenCalled();

      findCollapsibleListbox().vm.$emit('select', [mockLabels[0].title]);
      expect(mockAlertDismiss).toHaveBeenCalled();
    });
  });

  describe('fetching labels', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once labels are loaded', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items).toHaveLength(mockLabels.length);
      });
    });
  });

  describe('default labels fail to load', () => {
    beforeEach(() => {
      return createWrapper({ labelsResolver: jest.fn().mockRejectedValue(new Error('error')) });
    });

    it('stops the loading state', () => {
      expect(findCollapsibleListbox().props().searching).toBe(false);
    });

    it('emits an error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching label data for the selected group',
      });
    });
  });

  describe('when searching', () => {
    const results = mockLabels.slice(0, 1);

    beforeEach(async () => {
      await createWrapper({
        labelsResolver: jest.fn().mockResolvedValue(createMockLabelsResponse(results)),
      });

      findCollapsibleListbox().vm.$emit('search', 'query');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once request finishes', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the searching state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items).toHaveLength(results.length);
      });
    });
  });
});
