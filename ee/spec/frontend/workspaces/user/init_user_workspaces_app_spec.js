import { escape } from 'lodash-es';
import { createWrapper } from '@vue/test-utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import waitForPromises from 'helpers/wait_for_promises';
import { initUserWorkspacesApp } from 'ee/workspaces/user/init_user_workspaces_app';
import WorkspaceList from 'ee/workspaces/user/pages/list.vue';
import WorkspacesBreadcrumbs from 'ee/workspaces/user/components/workspaces_breadcrumbs.vue';
import { resetHTMLFixture, setHTMLFixture } from 'helpers/fixtures';

jest.mock('~/lib/logger');
jest.mock('~/lib/utils/breadcrumbs');

describe('ee/workspaces/init_user_workspaces_app', () => {
  let wrapper;

  beforeEach(() => {
    const options = JSON.stringify({
      workspaces_list_path: '/aaa',
      empty_state_svg_path: '/bbb',
    });

    setHTMLFixture(`<div id="js-workspaces" data-options="${escape(options)}"></div>`);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('initWorkspacesApp - integration', () => {
    beforeEach(async () => {
      wrapper = createWrapper(initUserWorkspacesApp());

      await waitForPromises();
    });

    it('creates router', () => {
      expect(wrapper.vm.$router).not.toBe(undefined);
    });

    it('renders list component', () => {
      const workspaceListComponent = wrapper.findComponent(WorkspaceList);

      expect(workspaceListComponent.exists()).toBe(true);
    });

    it('inits breadcrumbs', () => {
      expect(injectVueAppBreadcrumbs).toHaveBeenCalledWith(
        expect.any(Object),
        WorkspacesBreadcrumbs,
      );
    });
  });

  describe('initWorkspacesApp - when mounting element not found', () => {
    it('returns null', () => {
      document.body.innerHTML = '<div>Look ma! Code!</div>';

      expect(initUserWorkspacesApp()).toBeNull();
    });
  });
});
