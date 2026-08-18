import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HiddenGroupsItem from 'ee/approvals/components/hidden_groups_item.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

Vue.use(Vuex);

describe('Approvals HiddenGroupsItem', () => {
  let wrapper;

  const factory = (options = {}) => {
    wrapper = extendedWrapper(
      shallowMount(HiddenGroupsItem, {
        ...options,
        directives: {
          GlTooltip: createMockDirective('gl-tooltip'),
        },
        stubs: { HelpIcon },
      }),
    );
  };

  const findFolderIcon = () => wrapper.findComponentByTestId('folder-icon');
  const findHelpIcon = () => wrapper.findByTestId('help-icon');

  beforeEach(() => {
    factory();
  });

  it('contains the correct text', () => {
    expect(wrapper.text()).toContain('Private group(s)');
  });

  it('shows a folder icon', () => {
    const folderIcon = findFolderIcon();

    expect(folderIcon.element.tagName).toBe('GL-ICON-STUB');
    expect(folderIcon.props('name')).toBe('folder');
  });

  it('shows a help-icon with a tooltip', () => {
    const helpIcon = findHelpIcon();
    const tooltip = getBinding(helpIcon.element, 'gl-tooltip');

    expect(helpIcon.element.tagName).toBe('GL-ICON-STUB');
    expect(helpIcon.attributes('name')).toBe('question-o');

    expect(tooltip).not.toBe(undefined);
    expect(helpIcon.attributes('title')).toBe(`One or more groups that you don't have access to.`);
  });
});
