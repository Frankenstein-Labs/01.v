import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlBreadcrumb as mockGlBreadcrumb } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import RecursiveBreadcrumbs from 'ee/security_inventory/components/recursive_breadcrumbs.vue';
import { hasReachedMainGroup as mockHasReachedMainGroup } from 'ee/security_inventory/utils';
import { mockGroupAvatarAndParent } from '../mock_data';

Vue.use(VueApollo);

jest.mock('ee/security_inventory/components/recursive_breadcrumbs.vue', () => ({
  name: 'RecursiveBreadcrumbs',
  props: ['items', 'currentPath', 'groupFullPath'],
  data: () => ({ group: mockGroupAvatarAndParent }),
  render(h) {
    // in Vue 3: this.propName; in Vue 2: this._props.propName
    // eslint-disable-next-line no-underscore-dangle
    const { currentPath, groupFullPath, items = [] } = this || this._props;

    const currentCrumb = {
      text: this.group.name,
      to: { hash: currentPath },
      avatarPath: this.group.avatarUrl,
    };

    if (mockHasReachedMainGroup(currentPath, groupFullPath, this.group)) {
      return h(mockGlBreadcrumb, {
        props: {
          items: [currentCrumb, ...items],
        },
      });
    }

    return h(
      'RecursiveBreadcrumbs',
      {
        props: {
          groupFullPath,
          currentPath,
          items,
        },
      },
      [
        h('RecursiveBreadcrumbs', {
          props: {
            groupFullPath,
            currentPath: this.group.parent.fullPath,
            items: [currentCrumb, ...items],
          },
        }),
      ],
    );
  },
}));

describe('RecursiveBreadcrumbs', () => {
  let wrapper;

  const BreadcrumbWithText = (text) => ({ text, to: {} });
  const items = [BreadcrumbWithText('to'), BreadcrumbWithText('group')];
  const findGlBreadcrumb = () => wrapper.findComponent(mockGlBreadcrumb);
  const findRecursiveBreadcrumbAt = (i) => wrapper.findAllComponents(RecursiveBreadcrumbs).at(i);

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(RecursiveBreadcrumbs, {
      propsData: {
        ...options.props,
      },
      stubs: {
        RecursiveBreadcrumbs: stubComponent(RecursiveBreadcrumbs, {
          props: ['currentPath', 'groupFullPath', 'items'],
        }),
      },
    });
  };

  describe('when recursion has reached the main group', () => {
    beforeEach(() => {
      createComponent({
        props: { items, currentPath: 'path/to/group', groupFullPath: 'path/to/group' },
      });
    });

    it('renders the GlBreadcrumb component', () => {
      expect(findGlBreadcrumb().props('items')).toStrictEqual([
        { text: 'group', to: { hash: 'path/to/group' }, avatarPath: 'path/to/avatar' },
        ...items,
      ]);
    });
  });

  describe('when recursion has not reached the main group', () => {
    beforeEach(() => {
      createComponent({
        props: { items, currentPath: 'path/to/group', groupFullPath: 'path' },
      });
    });

    it('adds an item to the array and renders itself for the parent group', () => {
      // outer component: current group
      expect(findRecursiveBreadcrumbAt(0).props()).toStrictEqual({
        currentPath: 'path/to/group',
        groupFullPath: 'path',
        items,
      });

      // inner component: parent group
      expect(findRecursiveBreadcrumbAt(1).props()).toStrictEqual({
        currentPath: 'path/to',
        groupFullPath: 'path',
        items: [
          { text: 'group', to: { hash: 'path/to/group' }, avatarPath: 'path/to/avatar' },
          ...items,
        ],
      });
    });
  });
});
