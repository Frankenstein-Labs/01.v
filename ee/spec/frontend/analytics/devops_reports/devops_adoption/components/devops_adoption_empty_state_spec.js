import { GlEmptyState } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-groups-md.svg?url';
import DevopsAdoptionEmptyState from 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_empty_state.vue';
import {
  I18N_EMPTY_STATE_TITLE,
  I18N_EMPTY_STATE_DESCRIPTION,
} from 'ee/analytics/devops_reports/devops_adoption/constants';

describe('DevopsAdoptionEmptyState', () => {
  let wrapper;

  const createComponent = (options = {}) => {
    const { stubs = {}, props = {} } = options;

    return shallowMount(DevopsAdoptionEmptyState, {
      propsData: {
        hasGroupsData: true,
        ...props,
      },
      stubs,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  it('contains the correct svg', () => {
    wrapper = createComponent();

    expect(findEmptyState().props('svgPath')).toBe(EMPTY_STATE_SVG);
  });

  it('contains the correct text', () => {
    wrapper = createComponent();

    const emptyState = findEmptyState();

    expect(emptyState.props('title')).toBe(I18N_EMPTY_STATE_TITLE);
    expect(emptyState.props('description')).toBe(I18N_EMPTY_STATE_DESCRIPTION);
  });
});
