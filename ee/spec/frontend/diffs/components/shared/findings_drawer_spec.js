import Vue, { nextTick } from 'vue';
import { GlDrawer, GlTab, GlTabs } from '@gitlab/ui';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import FindingsDrawer from 'ee/diffs/components/shared/findings_drawer.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FindingsDrawerDetails from 'ee/diffs/components/shared/findings_drawer_details.vue';
import VulnerabilityCodeFlow from 'ee/vue_shared/components/code_flow/vulnerability_code_flow.vue';
import {
  mockFindingDismissed,
  mockFindingDetected,
  mockProject,
  mockFindingsMultiple,
  mockFindingDetails,
} from 'jest/diffs/mock_data/findings_drawer';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';

Vue.use(PiniaVuePlugin);

describe('FindingsDrawer', () => {
  let wrapper;
  let pinia;

  const findingDrawerProps = {
    drawer: { findings: [mockFindingDetected], index: 0 },
    project: mockProject,
  };

  const createWrapper = ({ findingDrawerOverrides = {}, mountFn = mountExtended } = {}) => {
    const propsData = {
      drawer: findingDrawerProps.drawer,
      project: findingDrawerProps.project,
      ...findingDrawerOverrides,
    };

    wrapper = mountFn(FindingsDrawer, {
      propsData,
      pinia,
    });
  };

  const findPreviousButton = () => wrapper.findByTestId('findings-drawer-prev-button');
  const findNextButton = () => wrapper.findByTestId('findings-drawer-next-button');
  const findTitle = () => wrapper.findByTestId('findings-drawer-title');
  const findVulnerabilityDetails = () => wrapper.findComponent(FindingsDrawerDetails);
  const findVulnerabilityCodeFlow = () => wrapper.findComponent(VulnerabilityCodeFlow);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findTabAtIndex = (index) => findAllTabs().at(index);

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs();
  });

  describe('General Rendering', () => {
    beforeEach(() => {
      createWrapper();
    });
    it('renders without errors', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('emits close event when gl-drawer emits close event', () => {
      wrapper.findComponent(GlDrawer).vm.$emit('close');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('matches the snapshot with dismissed badge', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('matches the snapshot with detected badge', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('Prev/Next Buttons with Multiple Items', () => {
    it('renders prev/next buttons when there are multiple items', () => {
      createWrapper({
        findingDrawerOverrides: { drawer: { findings: mockFindingsMultiple, index: 0 } },
      });
      expect(findPreviousButton().exists()).toBe(true);
      expect(findNextButton().exists()).toBe(true);
    });

    it('does not render prev/next buttons when there is only one item', () => {
      createWrapper({
        findingDrawerOverrides: { drawer: { findings: [mockFindingDismissed], index: 0 } },
      });
      expect(findPreviousButton().exists()).toBe(false);
      expect(findNextButton().exists()).toBe(false);
    });

    it('calls prev method on prev button click and loops correct drawerIndex', async () => {
      createWrapper({
        findingDrawerOverrides: { drawer: { findings: mockFindingsMultiple, index: 0 } },
      });
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);

      await findPreviousButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[2].title}`);

      await findPreviousButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[1].title}`);
    });

    it('calls next method on next button click', async () => {
      createWrapper({
        findingDrawerOverrides: { drawer: { findings: mockFindingsMultiple, index: 0 } },
      });
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[1].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[2].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);
    });
  });

  describe('when `details` object is not empty', () => {
    beforeEach(() => {
      createWrapper({
        findingDrawerOverrides: {
          drawer: {
            findings: [
              {
                ...mockFindingDismissed,
                details: mockFindingDetails,
              },
            ],
            index: 0,
          },
        },
        mountFn: shallowMountExtended,
      });
    });

    it('tabs should be shown', () => {
      expect(findAllTabs()).toHaveLength(2);
      expect(findTabs().exists()).toBe(true);
    });

    describe.each`
      title          | finderFn                     | index
      ${'Details'}   | ${findVulnerabilityDetails}  | ${0}
      ${'Code flow'} | ${findVulnerabilityCodeFlow} | ${1}
    `('Tabs', ({ title, finderFn, index }) => {
      it(`renders tab with a title ${title} at index ${index}`, () => {
        expect(findTabAtIndex(index).attributes('title')).toBe(title);
      });

      it(`renders ${title} component`, () => {
        expect(finderFn().exists()).toBe(true);
      });
    });
  });

  describe('when `details` object is empty', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not show the tabs', () => {
      expect(findTabs().exists()).toBe(false);
    });

    it('render `findVulnerabilityDetails` component without tabs', () => {
      expect(findVulnerabilityDetails().exists()).toBe(true);
    });
  });
});
