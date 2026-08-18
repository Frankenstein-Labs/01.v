import Vue from 'vue';
import { RouterLinkStub } from '@vue/test-utils';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HeaderArea from '~/repository/components/header_area.vue';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import CompactCodeDropdown from 'ee_component/repository/components/code_dropdown/compact_code_dropdown.vue';
import BlobControls from '~/repository/components/header_area/blob_controls.vue';
import { headerAppInjected } from 'ee_else_ce_jest/repository/mock_data';
import { useFileTreeBrowserVisibility } from '~/repository/stores/file_tree_browser_visibility';
import { useMainContainer } from '~/pinia/global_stores/main_container';

const defaultMockRoute = {
  params: {
    path: '/directory',
  },
  meta: {
    refType: '',
  },
  query: {
    ref_type: '',
  },
};

Vue.use(PiniaVuePlugin);

describe('HeaderArea', () => {
  let wrapper;
  let pinia;

  const findLockDirectoryButton = () => wrapper.findComponent(LockDirectoryButton);
  const findCompactCodeDropdown = () => wrapper.findComponent(CompactCodeDropdown);
  const findBlobControls = () => wrapper.findComponent(BlobControls);

  const createComponent = ({
    props = {},
    route = { name: 'treePathDecoded', params: { path: '/directory' } },
    provided = {},
    stubs = {},
  } = {}) => {
    return shallowMountExtended(HeaderArea, {
      provide: {
        ...headerAppInjected,
        ...provided,
      },
      propsData: {
        projectPath: 'test/project',
        historyLink: '/history',
        refType: 'branch',
        projectId: '123',
        currentRef: 'main',
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
        ...stubs,
      },
      mocks: {
        $route: {
          ...defaultMockRoute,
          ...route,
        },
      },
      pinia,
    });
  };

  beforeEach(() => {
    pinia = createTestingPinia({ stubActions: false });
    useMainContainer();
    useFileTreeBrowserVisibility();
    wrapper = createComponent();
  });

  describe('when rendered for tree view', () => {
    describe('Lock button', () => {
      it('renders Lock directory button for directories inside the project', async () => {
        // wait for the async LockDirectoryButton component to resolve
        await waitForPromises();

        expect(findLockDirectoryButton().exists()).toBe(true);
      });

      it('does not render Lock directory button for root directory', async () => {
        wrapper = createComponent({ route: { name: 'treePathDecoded', params: { path: '/' } } });
        await waitForPromises();

        expect(findLockDirectoryButton().exists()).toBe(false);
      });
    });

    describe('CodeDropdown', () => {
      it('renders CompactCodeDropdown component with correct props for desktop layout', () => {
        wrapper = createComponent({
          provided: {
            newWorkspacePath: '/workspaces/new',
            organizationId: '1',
          },
          stubs: {
            CompactCodeDropdown,
          },
        });

        expect(findCompactCodeDropdown().exists()).toBe(true);
        expect(findCompactCodeDropdown().props('kerberosUrl')).toBe(headerAppInjected.kerberosUrl);
      });
    });
  });

  describe('when rendered for blob view', () => {
    describe.each`
      routeName
      ${'blobPathDecoded'}
      ${'blobPathEncoded'}
    `('with route name $routeName', ({ routeName }) => {
      beforeEach(() => {
        wrapper = createComponent({
          route: { name: routeName },
        });
      });

      it('renders BlobControls; file locks surface through its lock button', () => {
        expect(findBlobControls().exists()).toBe(true);
        expect(findLockDirectoryButton().exists()).toBe(false);
      });
    });
  });
});
