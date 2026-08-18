import { GlEmptyState } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ValueStreamEmptyState from 'ee/analytics/cycle_analytics/components/value_stream_empty_state.vue';
import {
  EMPTY_STATE_ACTION_TEXT,
  EMPTY_STATE_SECONDARY_TEXT,
  EMPTY_STATE_FILTER_ERROR_TITLE,
  EMPTY_STATE_TITLE,
  EMPTY_STATE_FILTER_ERROR_DESCRIPTION,
  EMPTY_STATE_DESCRIPTION,
} from 'ee/analytics/cycle_analytics/constants';
import { newValueStreamPath } from 'ee_jest/analytics/cycle_analytics/mock_data';

const emptyStateSvgPath = '/path/to/svg';

describe('ValueStreamEmptyState', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamEmptyState, {
      propsData: {
        emptyStateSvgPath,
        hasDateRangeError: false,
        canEdit: true,
        ...props,
      },
      provide: {
        newValueStreamPath,
        ...provide,
      },
      stubs: { GlEmptyState },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTitle = () => findEmptyState().props('title');
  const findDescription = () => findEmptyState().props('description');
  const findPrimaryAction = () => wrapper.findByTestId('create-value-stream-button');
  const findSecondaryAction = () => wrapper.findByTestId('learn-more-link');

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the empty state title message', () => {
      expect(findTitle()).toEqual(EMPTY_STATE_TITLE);
    });

    it('renders the empty state description message', () => {
      expect(findDescription()).toBe(EMPTY_STATE_DESCRIPTION);
    });

    it('renders the new value stream button', () => {
      expect(findPrimaryAction().exists()).toBe(true);
      expect(findPrimaryAction().text()).toContain(EMPTY_STATE_ACTION_TEXT);
      expect(findPrimaryAction().attributes('href')).toBe(newValueStreamPath);
    });

    it('renders the learn more button', () => {
      expect(findSecondaryAction().exists()).toBe(true);
      expect(findSecondaryAction().text()).toBe(EMPTY_STATE_SECONDARY_TEXT);
      expect(findSecondaryAction().attributes('href')).toBe(
        '/help/user/group/value_stream_analytics/_index#create-a-value-stream',
      );
    });
  });

  describe('canEdit = false', () => {
    beforeEach(() => {
      createComponent({
        props: {
          canEdit: false,
        },
      });
    });

    it('does not render the new value stream button', () => {
      expect(findPrimaryAction().exists()).toBe(false);
    });

    it('does not render the learn more button', () => {
      expect(findSecondaryAction().exists()).toBe(false);
    });
  });

  describe('hasDateRangeError = true', () => {
    beforeEach(() => {
      createComponent({
        props: {
          hasDateRangeError: true,
        },
      });
    });

    it('renders the error title message', () => {
      expect(findTitle()).toEqual(EMPTY_STATE_FILTER_ERROR_TITLE);
    });

    it('renders the error description message', () => {
      expect(findDescription()).toBe(EMPTY_STATE_FILTER_ERROR_DESCRIPTION);
    });

    it('does not render the new value stream button', () => {
      expect(findPrimaryAction().exists()).toBe(false);
    });

    it('does not render the learn more button', () => {
      expect(findSecondaryAction().exists()).toBe(false);
    });
  });
});
