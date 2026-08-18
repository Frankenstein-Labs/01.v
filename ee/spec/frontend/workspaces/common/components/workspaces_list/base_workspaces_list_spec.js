import { shallowMount } from '@vue/test-utils';
import { GlSkeletonLoader, GlAlert, GlLink } from '@gitlab/ui';

import BaseWorkspacesList from 'ee/workspaces/common/components/workspaces_list/base_workspaces_list.vue';
import WorkspaceEmptyState from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

const findAlert = (wrapper) => wrapper.findComponent(GlAlert);
const findIndexLayout = (wrapper) => wrapper.findComponent(IndexLayout);
const findLearnMoreLink = (wrapper) => wrapper.findComponent(GlLink);
const HEADER_SLOT_TESTID = 'header-slot-content';

describe('workspaces/common/components/workspaces_list/base_workspaces_list.vue', () => {
  let wrapper;

  function createWrapper(props) {
    wrapper = extendedWrapper(
      shallowMount(BaseWorkspacesList, {
        propsData: {
          empty: true,
          loading: false,
          error: null,
          newWorkspacePath: '/some-path',
          ...props,
        },
        slots: {
          header: `<div data-testid="${HEADER_SLOT_TESTID}"></div>`,
        },
        stubs: {
          IndexLayout,
          PageHeading,
        },
      }),
    );
  }

  const findHeaderSlot = () => wrapper.findByTestId(HEADER_SLOT_TESTID);

  describe('is loading', () => {
    beforeEach(() => {
      createWrapper({
        empty: true,
        loading: true,
      });
    });

    it('does not render empty state', () => {
      const emptyState = wrapper.findComponent(WorkspaceEmptyState);
      expect(emptyState.exists()).toBe(false);
    });
  });

  describe('is empty', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders an empty state', () => {
      expect(wrapper.findComponent(WorkspaceEmptyState).exists()).toBe(true);
    });

    it('hides the heading', () => {
      expect(findIndexLayout(wrapper).props('pageHeadingSrOnly')).toBe(true);
    });

    it('does not render the Learn more link', () => {
      expect(findLearnMoreLink(wrapper).exists()).toBe(false);
    });

    it('does not render the header slot', () => {
      expect(findHeaderSlot().exists()).toBe(false);
    });

    it('does not render error', () => {
      expect(findAlert(wrapper).exists()).toBe(false);
    });
  });

  describe('is not empty', () => {
    beforeEach(() => {
      createWrapper({
        empty: false,
        loading: false,
      });
    });

    it('does not render loading state', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(false);
    });

    it('does not render empty state', () => {
      expect(wrapper.findComponent(WorkspaceEmptyState).exists()).toBe(false);
    });

    it('shows the heading', () => {
      expect(findIndexLayout(wrapper).props('pageHeadingSrOnly')).toBe(false);
    });

    it('renders the Learn more link', () => {
      expect(findLearnMoreLink(wrapper).exists()).toBe(true);
    });

    it('renders the header slot', () => {
      expect(findHeaderSlot().exists()).toBe(true);
    });

    it('does not render error', () => {
      expect(findAlert(wrapper).exists()).toBe(false);
    });
  });

  describe('on error', () => {
    const MOCK_ERROR =
      'Unable to load current workspaces. Please try again or contact an administrator.';

    beforeEach(() => {
      createWrapper({
        empty: false,
        loading: false,
        error: MOCK_ERROR,
      });
    });

    it('shows alert', () => {
      expect(findAlert(wrapper).text()).toBe(MOCK_ERROR);
    });
  });
});
