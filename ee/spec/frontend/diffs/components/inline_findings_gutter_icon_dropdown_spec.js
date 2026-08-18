import Vue, { nextTick } from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import inlineFindingsGutterIconDropdown from 'ee/diffs/components/inline_findings_gutter_icon_dropdown.vue';
import inlineFindingsDropdown from 'ee/diffs/components/inline_findings_dropdown.vue';
import { ignoreConsoleMessages } from 'helpers/console_watcher';
import {
  fiveCodeQualityFindings,
  singularCodeQualityFinding,
  singularSastFinding,
  filePath,
} from 'jest/diffs/mock_data/inline_findings';
import { useFindingsDrawer } from '~/mr_notes/store/findings_drawer';

Vue.use(PiniaVuePlugin);

let pinia;
let wrapper;

const findInlineFindingsDropdown = () => wrapper.findComponent(inlineFindingsDropdown);
const findMoreCount = () => wrapper.findByTestId('inline-findings-more-count');
const findDropdownItems = () => wrapper.findAll('.gl-new-dropdown-item-content');
const createComponent = (
  props = {
    filePath,
    codeQuality: singularCodeQualityFinding,
  },
) => {
  wrapper = mountExtended(inlineFindingsGutterIconDropdown, { propsData: props, pinia });
};

describe('EE inlineFindingsGutterIconDropdown', () => {
  beforeEach(() => {
    pinia = createTestingPinia({ stubActions: false });
  });

  describe('code Quality gutter icon', () => {
    ignoreConsoleMessages([/\[Vue warn\]: \(deprecation TRANSITION_GROUP_ROOT\)/]);

    it('renders correctly', () => {
      createComponent({
        filePath,
        codeQuality: singularCodeQualityFinding,
        sast: singularSastFinding,
      });

      expect(findInlineFindingsDropdown().exists()).toBe(true);
    });

    describe('more count', () => {
      it('renders when there are more than 3 findings and icon is hovered', async () => {
        createComponent({
          filePath: '/',
          codeQuality: fiveCodeQualityFindings,
        });

        findInlineFindingsDropdown().vm.$emit('mouseenter');
        await nextTick();

        expect(findMoreCount().text()).toBe('2');
      });

      it('does not render when there are less than 3 findings and icon is hovered', async () => {
        createComponent({
          filePath: '/',
          codeQuality: singularCodeQualityFinding,
        });

        findInlineFindingsDropdown().vm.$emit('mouseenter');
        await nextTick();

        expect(findMoreCount().exists()).toBe(false);
      });
    });

    describe('groupedFindings', () => {
      it('calls setDrawer action when an item action is triggered', async () => {
        createComponent({
          filePath,
          codeQuality: singularCodeQualityFinding,
          sast: singularSastFinding,
        });

        const itemElements = findDropdownItems();

        // check for CodeQuality
        await itemElements.at(0).trigger('click');
        expect(useFindingsDrawer().setDrawer).toHaveBeenCalledTimes(1);

        // check for SAST
        await itemElements.at(1).trigger('click');
        expect(useFindingsDrawer().setDrawer).toHaveBeenCalledTimes(2);
      });

      it('calls setDrawer action with correct allLineFindings and index when an item action is triggered', async () => {
        createComponent({
          filePath,
          codeQuality: singularCodeQualityFinding,
          sast: singularSastFinding,
        });

        const itemElements = findDropdownItems();
        await itemElements.at(0).trigger('click');

        expect(useFindingsDrawer().setDrawer).toHaveBeenNthCalledWith(1, {
          findings: [
            {
              ...singularCodeQualityFinding[0],
              action: expect.any(Function),
              class: 'gl-text-orange-300',
              name: 'severity-low',
            },
            {
              ...singularSastFinding[0],
              action: expect.any(Function),
              class: 'gl-text-orange-300',
              name: 'severity-low',
            },
          ],
          index: 0,
        });

        await itemElements.at(1).trigger('click');

        expect(useFindingsDrawer().setDrawer).toHaveBeenNthCalledWith(2, {
          findings: [
            {
              ...singularCodeQualityFinding[0],
              action: expect.any(Function),
              class: 'gl-text-orange-300',
              name: 'severity-low',
            },
            {
              ...singularSastFinding[0],
              action: expect.any(Function),
              class: 'gl-text-orange-300',
              name: 'severity-low',
            },
          ],
          index: 1,
        });
      });
    });

    it('sets "isHoveringFirstIcon" to true when mouse enters the first icon', async () => {
      createComponent();

      findInlineFindingsDropdown().vm.$emit('mouseenter');
      await nextTick();

      expect(wrapper.vm.isHoveringFirstIcon).toBe(true);
    });

    it('sets "isHoveringFirstIcon" to false when mouse leaves the first icon', async () => {
      createComponent();

      findInlineFindingsDropdown().vm.$emit('mouseleave');
      await nextTick();

      expect(wrapper.vm.isHoveringFirstIcon).toBe(false);
    });
  });
});
